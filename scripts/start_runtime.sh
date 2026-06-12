#!/usr/bin/env bash
set -euo pipefail

# Starts the P0 runtime pipeline using only project-local state, logs, and PID files.
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
RUNTIME_DIR="$REPO_ROOT/runtime"
RUN_DIR="$RUNTIME_DIR/run/p0_runtime"
LOG_DIR="$RUNTIME_DIR/logs/runtime"
RESULT_DIR="$RUNTIME_DIR/results"
MANIFEST="$RUN_DIR/manifest.tsv"
STATUS_FILE="$RUN_DIR/status.txt"
START_LOG="$LOG_DIR/start_runtime.log"
ROS_SETUP="/opt/ros/humble/setup.bash"
WORKSPACE_SETUP="$REPO_ROOT/ros2_ws/install/setup.bash"
SYSTEM_SAMPLE_FILE="$REPO_ROOT/ros2_ws/src/edge_reliability_system/testdata/tegrastats_samples.txt"
SYSTEM_RAW_LOG="$LOG_DIR/system_metrics_raw.log"
HEALTH_CONFIG="$REPO_ROOT/ros2_ws/src/edge_reliability_health/config/health_monitor_system_nominal.yaml"

SENSOR_TOPIC="/edge/sensors/fake_primary"
METRICS_TOPIC="/edge/metrics/pipeline"
SYSTEM_TOPIC="/edge/metrics/system"
HEALTH_TOPIC="/edge/health/state"
SENSOR_TYPE="edge_reliability_msgs/msg/SensorSample"
METRICS_TYPE="edge_reliability_msgs/msg/PipelineMetrics"
SYSTEM_TYPE="edge_reliability_msgs/msg/SystemMetrics"
HEALTH_TYPE="edge_reliability_msgs/msg/HealthState"

STARTED_PIDS=()

mkdir -p "$RUN_DIR" "$LOG_DIR" "$RESULT_DIR"

log() {
  local message="$1"
  printf '%s %s\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)" "$message" | tee -a "$START_LOG"
}

fail() {
  local message="$1"
  log "ERROR: $message"
  cleanup_started_processes
  exit 1
}

signal_process_tree() {
  local signal="$1"
  local pid="$2"
  local child
  local children

  if command -v pgrep >/dev/null 2>&1; then
    children="$(pgrep -P "$pid" 2>/dev/null || true)"
    for child in $children; do
      signal_process_tree "$signal" "$child"
    done
  fi

  kill -s "$signal" "$pid" 2>/dev/null || true
}

wait_for_process_exit() {
  local pid="$1"
  local seconds="$2"
  local deadline=$((SECONDS + seconds))

  while (( SECONDS < deadline )); do
    if ! kill -0 "$pid" 2>/dev/null; then
      return 0
    fi
    sleep 1
  done

  return 1
}

stop_process_tree() {
  local pid="$1"

  if [[ -z "$pid" ]] || ! kill -0 "$pid" 2>/dev/null; then
    return 0
  fi

  signal_process_tree INT "$pid"
  if wait_for_process_exit "$pid" 8; then
    return 0
  fi

  signal_process_tree TERM "$pid"
  if wait_for_process_exit "$pid" 5; then
    return 0
  fi

  signal_process_tree KILL "$pid"
  sleep 1
}

cleanup_started_processes() {
  local pid

  for pid in "${STARTED_PIDS[@]:-}"; do
    stop_process_tree "$pid"
  done
}

source_setup_with_nounset_disabled() {
  local setup_file="$1"
  local label="$2"
  local source_status=0

  if [[ ! -f "$setup_file" ]]; then
    fail "$label not found: $setup_file"
  fi

  set +u
  # shellcheck source=/dev/null
  source "$setup_file"
  source_status="$?"
  set -u

  if [[ "$source_status" -ne 0 ]]; then
    fail "failed to source $label"
  fi
}

manifest_has_live_processes() {
  local pid

  if [[ ! -f "$MANIFEST" ]]; then
    return 1
  fi

  while IFS=$'\t' read -r _label pid _log_file _command; do
    [[ "$pid" == "pid" || -z "$pid" ]] && continue
    if kill -0 "$pid" 2>/dev/null; then
      return 0
    fi
  done < "$MANIFEST"

  return 1
}

archive_stale_manifest() {
  local archive

  if [[ -f "$MANIFEST" ]]; then
    archive="$RUN_DIR/manifest.stale.$(date -u +%Y%m%dT%H%M%SZ).tsv"
    mv "$MANIFEST" "$archive"
    log "Archived stale manifest: $archive"
  fi
}

launch_component() {
  local label="$1"
  local log_file="$2"
  shift 2

  "$@" > "$log_file" 2>&1 &
  local pid="$!"
  STARTED_PIDS+=("$pid")

  sleep 3
  if ! kill -0 "$pid" 2>/dev/null; then
    fail "$label exited early; see $log_file"
  fi

  printf '%s\t%s\t%s\t%s\n' "$label" "$pid" "$log_file" "$*" >> "$MANIFEST"
  log "Started $label pid=$pid log=$log_file"
}

wait_for_topic_type() {
  local topic="$1"
  local topic_type="$2"
  local timeout_seconds="${3:-30}"
  local deadline=$((SECONDS + timeout_seconds))
  local topic_list="$RESULT_DIR/start_runtime_topic_list_typed.txt"

  while (( SECONDS < deadline )); do
    ros2 topic list -t > "$topic_list" 2>&1 || true
    if grep -F "$topic [$topic_type]" "$topic_list" >/dev/null 2>&1; then
      return 0
    fi
    sleep 1
  done

  return 1
}

: > "$START_LOG"
log "Starting P0 runtime from $REPO_ROOT"

if manifest_has_live_processes; then
  fail "runtime manifest already contains live processes; run scripts/stop_runtime.sh first"
fi

archive_stale_manifest
printf 'label\tpid\tlog_file\tcommand\n' > "$MANIFEST"

if [[ -f "$SCRIPT_DIR/setup_runtime_dirs.sh" ]]; then
  bash "$SCRIPT_DIR/setup_runtime_dirs.sh" >> "$START_LOG" 2>&1 || fail "setup_runtime_dirs.sh failed"
fi

source_setup_with_nounset_disabled "$ROS_SETUP" "ROS 2 Humble setup"
source_setup_with_nounset_disabled "$WORKSPACE_SETUP" "ros2_ws install setup"

if [[ ! -f "$SYSTEM_SAMPLE_FILE" ]]; then
  fail "system metrics sample file not found: $SYSTEM_SAMPLE_FILE"
fi

if [[ ! -f "$HEALTH_CONFIG" ]]; then
  fail "health monitor config not found: $HEALTH_CONFIG"
fi

ros2 daemon start >> "$START_LOG" 2>&1 || true

launch_component "fake_sensor" "$LOG_DIR/fake_sensor_launch.log" \
  ros2 launch edge_reliability_fake_sensor fake_sensor.launch.py

launch_component "processor" "$LOG_DIR/processor_launch.log" \
  ros2 launch edge_reliability_processor processor.launch.py

launch_component "system_metrics" "$LOG_DIR/system_metrics_launch.log" \
  ros2 launch edge_reliability_system system_metrics.launch.py \
    "sample_file:=$SYSTEM_SAMPLE_FILE" "raw_log_path:=$SYSTEM_RAW_LOG" "disk_path:=$REPO_ROOT"

launch_component "health_monitor" "$LOG_DIR/health_monitor_launch.log" \
  ros2 launch edge_reliability_health health_monitor.launch.py "config_file:=$HEALTH_CONFIG"

if ! wait_for_topic_type "$SENSOR_TOPIC" "$SENSOR_TYPE" 30; then
  fail "sensor topic did not become ready: $SENSOR_TOPIC"
fi
if ! wait_for_topic_type "$METRICS_TOPIC" "$METRICS_TYPE" 30; then
  fail "pipeline metrics topic did not become ready: $METRICS_TOPIC"
fi
if ! wait_for_topic_type "$SYSTEM_TOPIC" "$SYSTEM_TYPE" 30; then
  fail "system metrics topic did not become ready: $SYSTEM_TOPIC"
fi
if ! wait_for_topic_type "$HEALTH_TOPIC" "$HEALTH_TYPE" 30; then
  fail "health topic did not become ready: $HEALTH_TOPIC"
fi

{
  echo "status=running"
  echo "started_at_utc=$(date -u +%Y-%m-%dT%H:%M:%SZ)"
  echo "repo_root=$REPO_ROOT"
  echo "manifest=$MANIFEST"
  echo "log_dir=$LOG_DIR"
  echo "topics=$SENSOR_TOPIC,$METRICS_TOPIC,$SYSTEM_TOPIC,$HEALTH_TOPIC"
} > "$STATUS_FILE"

log "P0 runtime started"
log "Manifest: $MANIFEST"
log "Logs: $LOG_DIR"
