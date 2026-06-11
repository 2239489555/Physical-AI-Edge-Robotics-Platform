#!/usr/bin/env bash
set -uo pipefail

# Runs the P0-011 system metrics node using saved tegrastats samples.
# Runtime outputs stay under runtime/results, runtime/logs, and runtime/artifacts/preflight.
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
RUNTIME_DIR="$REPO_ROOT/runtime"
ARTIFACT_DIR="$RUNTIME_DIR/artifacts/preflight"
LOG_DIR="$RUNTIME_DIR/logs"
TEGRALOG_DIR="$LOG_DIR/tegrastats"
RESULT_DIR="$RUNTIME_DIR/results"

SYSTEM_TOPIC="/edge/metrics/system"
SYSTEM_TYPE="edge_reliability_msgs/msg/SystemMetrics"
SAMPLE_FILE="$REPO_ROOT/ros2_ws/src/edge_reliability_system/testdata/tegrastats_samples.txt"
RAW_LOG="$TEGRALOG_DIR/p0_011_system_metrics_raw.log"
LIVE_PROBE_LOG="$TEGRALOG_DIR/p0_011_live_tegrastats_probe.log"

BUILD_LOG="$ARTIFACT_DIR/p0_011_colcon_build.txt"
TEST_LOG="$ARTIFACT_DIR/p0_011_colcon_test.txt"
TEST_RESULT_LOG="$ARTIFACT_DIR/p0_011_colcon_test_result.txt"
GIT_STATUS="$RESULT_DIR/p0_011_git_status.txt"
REPORT="$RESULT_DIR/p0_011_smoke_report.txt"
LAUNCH_LOG="$LOG_DIR/p0_011_system_metrics_launch.txt"
LAUNCH_PROCESS="$RESULT_DIR/p0_011_system_metrics_launch_process.txt"
TOPIC_LIST="$RESULT_DIR/p0_011_topic_list_typed.txt"
TOPIC_INFO="$RESULT_DIR/p0_011_topic_info_verbose.txt"
SUMMARY="$RESULT_DIR/p0_011_system_metrics_summary.txt"

COLCON_STATUS="not_run"
COLCON_TEST_STATUS="not_run"
VERDICT="PASS"
BLOCKER="-"
ACTIVE_SYSTEM_PID=""

SYSTEM_MESSAGES=""
CPU_PERCENT=""
MEMORY_USED_MB=""
MEMORY_TOTAL_MB=""
GPU_PERCENT=""
TEMPERATURE_C=""
POWER_W=""
SOURCE_VALUE=""
RAW_LOG_LINES=""
LIVE_TEGRASTATS_STATUS="not_checked"

CLEANUP_INT_WAIT_SECONDS=8
CLEANUP_TERM_WAIT_SECONDS=5

mkdir -p "$ARTIFACT_DIR" "$LOG_DIR" "$TEGRALOG_DIR" "$RESULT_DIR"
: > "$RAW_LOG"
: > "$LIVE_PROBE_LOG"

trap cleanup_launches EXIT

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

  kill "-$signal" "$pid" 2>/dev/null || true
}

wait_for_background_process_exit() {
  local pid="$1"
  local wait_seconds="$2"
  local deadline=$((SECONDS + wait_seconds))

  while (( SECONDS < deadline )); do
    if ! kill -0 "$pid" 2>/dev/null; then
      wait "$pid" 2>/dev/null || true
      return 0
    fi
    sleep 1
  done

  return 1
}

stop_background_process() {
  local pid="$1"
  local label="$2"

  if [[ -z "$pid" ]]; then
    return 0
  fi

  if ! kill -0 "$pid" 2>/dev/null; then
    wait "$pid" 2>/dev/null || true
    return 0
  fi

  signal_process_tree INT "$pid"
  if wait_for_background_process_exit "$pid" "$CLEANUP_INT_WAIT_SECONDS"; then
    return 0
  fi

  echo "[cleanup] $label did not stop after SIGINT; sending SIGTERM" >&2
  signal_process_tree TERM "$pid"
  if wait_for_background_process_exit "$pid" "$CLEANUP_TERM_WAIT_SECONDS"; then
    return 0
  fi

  echo "[cleanup] $label did not stop after SIGTERM; sending SIGKILL" >&2
  signal_process_tree KILL "$pid"
  sleep 1
  wait "$pid" 2>/dev/null || true
}

cleanup_launches() {
  stop_background_process "${ACTIVE_SYSTEM_PID:-}" "system metrics launch"
  ACTIVE_SYSTEM_PID=""
}

print_head() {
  local file="$1"
  if [[ -f "$file" ]]; then
    sed -n '1,14p' "$file"
  else
    echo "(missing $file)"
  fi
}

print_tail() {
  local file="$1"
  if [[ -f "$file" ]]; then
    tail -n 14 "$file"
  else
    echo "(missing $file)"
  fi
}

print_summary_lines() {
  local file="$1"
  if [[ -f "$file" ]]; then
    grep -E '^(Starting|Finished|Summary:)' "$file" || true
  else
    echo "(missing $file)"
  fi
}

collect_git_status() {
  (
    cd "$REPO_ROOT" && git status --short --ignored
  ) > "$GIT_STATUS" 2>&1 || true
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

summary_value() {
  local key="$1"
  local file="$2"
  awk -v key="$key" '
    index($0, key ": ") == 1 {
      value = substr($0, length(key) + 3)
    }
    END { print value }
  ' "$file"
}

capture_system_metrics_summary() {
  local output_file="$1"
  local sample_seconds="${2:-6.0}"

  python3 - "$SYSTEM_TOPIC" "$sample_seconds" <<'PY' | tee "$output_file"
import sys
import time

import rclpy
from edge_reliability_msgs.msg import SystemMetrics
from rclpy.node import Node
from rclpy.qos import (
    QoSDurabilityPolicy,
    QoSHistoryPolicy,
    QoSProfile,
    QoSReliabilityPolicy,
)

topic = sys.argv[1]
sample_seconds = float(sys.argv[2])
messages = []


class SystemProbe(Node):
    def __init__(self):
        super().__init__("p0_011_system_probe")
        qos = QoSProfile(
            history=QoSHistoryPolicy.KEEP_LAST,
            depth=10,
            reliability=QoSReliabilityPolicy.RELIABLE,
            durability=QoSDurabilityPolicy.VOLATILE,
        )
        self.create_subscription(SystemMetrics, topic, self.on_metrics, qos)

    def on_metrics(self, message):
        messages.append(message)


rclpy.init()
node = SystemProbe()
deadline = time.monotonic() + sample_seconds

try:
    while time.monotonic() < deadline:
        rclpy.spin_once(node, timeout_sec=0.1)
finally:
    node.destroy_node()
    rclpy.shutdown()

print(f"system_messages: {len(messages)}")
if not messages:
    sys.exit(2)

last = messages[-1]
print(f"last_cpu_percent: {last.cpu_percent:.3f}")
print(f"last_memory_used_mb: {last.memory_used_mb:.3f}")
print(f"last_memory_total_mb: {last.memory_total_mb:.3f}")
print(f"last_gpu_percent: {last.gpu_percent:.3f}")
print(f"last_temperature_c: {last.temperature_c:.3f}")
print(f"last_power_w: {last.power_w:.3f}")
print(f"last_source: {last.source}")
PY
}

probe_live_tegrastats() {
  if ! command -v tegrastats >/dev/null 2>&1; then
    LIVE_TEGRASTATS_STATUS="unavailable"
    echo "tegrastats command unavailable" > "$LIVE_PROBE_LOG"
    return 0
  fi

  timeout --signal=INT 4s tegrastats --interval 1000 > "$LIVE_PROBE_LOG" 2>&1 || true
  if [[ -s "$LIVE_PROBE_LOG" ]]; then
    LIVE_TEGRASTATS_STATUS="available"
  else
    LIVE_TEGRASTATS_STATUS="failed"
  fi
}

write_report() {
  mkdir -p "$RESULT_DIR"
  {
    echo "P0-011_RESULT"
    echo
    echo "Build"
    echo "colcon exit status: $COLCON_STATUS"
    echo "build summary:"
    print_summary_lines "$BUILD_LOG"
    echo "build tail:"
    print_tail "$BUILD_LOG"
    echo
    echo "Unit Tests"
    echo "colcon test exit status: $COLCON_TEST_STATUS"
    echo "test tail:"
    print_tail "$TEST_LOG"
    echo "test-result tail:"
    print_tail "$TEST_RESULT_LOG"
    echo
    echo "System Metrics Topic"
    echo "topic list:"
    print_head "$TOPIC_LIST"
    echo "topic info:"
    print_head "$TOPIC_INFO"
    echo "system metrics summary:"
    print_head "$SUMMARY"
    echo "system messages: ${SYSTEM_MESSAGES:-unknown}"
    echo "cpu percent: ${CPU_PERCENT:-unknown}"
    echo "memory used mb: ${MEMORY_USED_MB:-unknown}"
    echo "memory total mb: ${MEMORY_TOTAL_MB:-unknown}"
    echo "gpu percent: ${GPU_PERCENT:-unknown}"
    echo "temperature c: ${TEMPERATURE_C:-unknown}"
    echo "power w: ${POWER_W:-unknown}"
    echo "source: ${SOURCE_VALUE:-unknown}"
    echo
    echo "Raw tegrastats Logs"
    echo "sample file: $SAMPLE_FILE"
    echo "raw tegrastats log path: $RAW_LOG"
    echo "raw tegrastats log lines: ${RAW_LOG_LINES:-unknown}"
    echo
    echo "Live tegrastats Probe"
    echo "live tegrastats status: $LIVE_TEGRASTATS_STATUS"
    echo "live tegrastats probe log: $LIVE_PROBE_LOG"
    echo "live tegrastats probe tail:"
    print_tail "$LIVE_PROBE_LOG"
    echo
    echo "Git / Runtime Hygiene"
    echo "git status:"
    print_head "$GIT_STATUS"
    echo "runtime artifact paths:"
    echo "$BUILD_LOG"
    echo "$TEST_LOG"
    echo "$TEST_RESULT_LOG"
    echo "$SUMMARY"
    echo "$RAW_LOG"
    echo "$LIVE_PROBE_LOG"
    echo "$REPORT"
    echo
    echo "Verdict"
    echo "PASS/FAIL: $VERDICT"
    echo "Blocker if FAIL: $BLOCKER"
  } | tee "$REPORT"
}

fail() {
  VERDICT="FAIL"
  BLOCKER="$1"
  cleanup_launches
  collect_git_status
  write_report
  exit 1
}

if [[ -f "$SCRIPT_DIR/setup_runtime_dirs.sh" ]]; then
  bash "$SCRIPT_DIR/setup_runtime_dirs.sh" || fail "setup_runtime_dirs.sh failed"
fi

source_setup_with_nounset_disabled /opt/ros/humble/setup.bash "ROS 2 Humble setup"

cd "$REPO_ROOT/ros2_ws" || fail "ros2_ws directory missing"

colcon build --packages-select edge_reliability_msgs edge_reliability_system --symlink-install \
  2>&1 | tee "$BUILD_LOG"
COLCON_STATUS="${PIPESTATUS[0]}"
if [[ "$COLCON_STATUS" -ne 0 ]]; then
  fail "colcon build failed"
fi

if grep -F "package had stderr output" "$BUILD_LOG" >/dev/null 2>&1; then
  fail "colcon build reported package stderr output"
fi

colcon test --packages-select edge_reliability_system \
  2>&1 | tee "$TEST_LOG"
COLCON_TEST_STATUS="${PIPESTATUS[0]}"
colcon test-result --verbose --test-result-base build/edge_reliability_system \
  > "$TEST_RESULT_LOG" 2>&1 || true
if [[ "$COLCON_TEST_STATUS" -ne 0 ]]; then
  fail "colcon test failed"
fi

source_setup_with_nounset_disabled install/setup.bash "ros2_ws install setup"

ros2 daemon stop >/dev/null 2>&1 || true
ros2 daemon start >/dev/null 2>&1 || true
sleep 2

ros2 launch edge_reliability_system system_metrics.launch.py \
  "sample_file:=$SAMPLE_FILE" \
  "raw_log_path:=$RAW_LOG" > "$LAUNCH_LOG" 2>&1 &
ACTIVE_SYSTEM_PID="$!"
sleep 4
if ! kill -0 "$ACTIVE_SYSTEM_PID" 2>/dev/null; then
  ps -p "$ACTIVE_SYSTEM_PID" -o pid,cmd > "$LAUNCH_PROCESS" 2>&1 || true
  fail "system metrics launch exited early"
fi
ps -p "$ACTIVE_SYSTEM_PID" -o pid,cmd > "$LAUNCH_PROCESS"

ros2 topic list -t | tee "$TOPIC_LIST"
ros2 topic info "$SYSTEM_TOPIC" -v | tee "$TOPIC_INFO"
capture_system_metrics_summary "$SUMMARY" 6
if [[ "$?" -ne 0 ]]; then
  fail "system metrics capture failed"
fi

if ! grep -F "event=startup" "$LAUNCH_LOG" >/dev/null 2>&1; then
  fail "system metrics startup log missing"
fi
if ! grep -F "event=first_publish" "$LAUNCH_LOG" >/dev/null 2>&1; then
  fail "system metrics first publish log missing"
fi

SYSTEM_MESSAGES="$(summary_value "system_messages" "$SUMMARY")"
CPU_PERCENT="$(summary_value "last_cpu_percent" "$SUMMARY")"
MEMORY_USED_MB="$(summary_value "last_memory_used_mb" "$SUMMARY")"
MEMORY_TOTAL_MB="$(summary_value "last_memory_total_mb" "$SUMMARY")"
GPU_PERCENT="$(summary_value "last_gpu_percent" "$SUMMARY")"
TEMPERATURE_C="$(summary_value "last_temperature_c" "$SUMMARY")"
POWER_W="$(summary_value "last_power_w" "$SUMMARY")"
SOURCE_VALUE="$(summary_value "last_source" "$SUMMARY")"
RAW_LOG_LINES="$(wc -l < "$RAW_LOG" 2>/dev/null || echo 0)"

awk -v count="$SYSTEM_MESSAGES" 'BEGIN { exit !(count >= 3) }'
if [[ "$?" -ne 0 ]]; then
  fail "system metrics message count too low: $SYSTEM_MESSAGES"
fi

awk -v used="$MEMORY_USED_MB" -v total="$MEMORY_TOTAL_MB" 'BEGIN { exit !(used > 0 && total > used) }'
if [[ "$?" -ne 0 ]]; then
  fail "memory metrics invalid: used=$MEMORY_USED_MB total=$MEMORY_TOTAL_MB"
fi

awk -v cpu="$CPU_PERCENT" -v gpu="$GPU_PERCENT" -v temp="$TEMPERATURE_C" -v power="$POWER_W" \
  'BEGIN { exit !(cpu >= 0 && gpu >= 0 && temp > 0 && power > 0) }'
if [[ "$?" -ne 0 ]]; then
  fail "system metrics numeric values invalid"
fi

if [[ "$SOURCE_VALUE" != "tegrastats_sample_file" ]]; then
  fail "unexpected system metrics source: $SOURCE_VALUE"
fi

if [[ -z "$RAW_LOG_LINES" ]] || [[ "$RAW_LOG_LINES" -le 0 ]]; then
  fail "raw tegrastats log was not written"
fi

probe_live_tegrastats
cleanup_launches
collect_git_status
write_report
