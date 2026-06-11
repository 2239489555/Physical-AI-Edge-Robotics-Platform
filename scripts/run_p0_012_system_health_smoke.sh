#!/usr/bin/env bash
set -uo pipefail

# Runs normal and system-pressure scenarios through health_monitor.
# Runtime outputs stay under runtime/results, runtime/logs, and runtime/artifacts/preflight.
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
RUNTIME_DIR="$REPO_ROOT/runtime"
ARTIFACT_DIR="$RUNTIME_DIR/artifacts/preflight"
LOG_DIR="$RUNTIME_DIR/logs"
TEGRALOG_DIR="$LOG_DIR/tegrastats"
RESULT_DIR="$RUNTIME_DIR/results"

HEALTH_TOPIC="/edge/health/state"
HEALTH_TYPE="edge_reliability_msgs/msg/HealthState"
PIPELINE_TOPIC="/edge/metrics/pipeline"
PIPELINE_TYPE="edge_reliability_msgs/msg/PipelineMetrics"
SYSTEM_TOPIC="/edge/metrics/system"
SYSTEM_TYPE="edge_reliability_msgs/msg/SystemMetrics"

FAKE_CONFIG="$REPO_ROOT/ros2_ws/src/edge_reliability_fake_sensor/config/fake_sensor.yaml"
PROCESSOR_CONFIG="$REPO_ROOT/ros2_ws/src/edge_reliability_processor/config/processor.yaml"
HEALTH_CONFIG="$REPO_ROOT/ros2_ws/src/edge_reliability_health/config/health_monitor_system_nominal.yaml"
PRESSURE_HEALTH_CONFIG="$REPO_ROOT/ros2_ws/src/edge_reliability_health/config/health_monitor_system_pressure.yaml"
SYSTEM_SAMPLE_FILE="$REPO_ROOT/ros2_ws/src/edge_reliability_system/testdata/tegrastats_samples.txt"

BUILD_LOG="$ARTIFACT_DIR/p0_012_colcon_build.txt"
TEST_LOG="$ARTIFACT_DIR/p0_012_colcon_test.txt"
HEALTH_TEST_RESULT_LOG="$ARTIFACT_DIR/p0_012_health_colcon_test_result.txt"
SYSTEM_TEST_RESULT_LOG="$ARTIFACT_DIR/p0_012_system_colcon_test_result.txt"
GIT_STATUS="$RESULT_DIR/p0_012_git_status.txt"
REPORT="$RESULT_DIR/p0_012_smoke_report.txt"

NORMAL_HEALTH_SUMMARY="$RESULT_DIR/p0_012_normal_health_summary.txt"
PRESSURE_HEALTH_SUMMARY="$RESULT_DIR/p0_012_system_pressure_health_summary.txt"
NORMAL_SYSTEM_SUMMARY="$RESULT_DIR/p0_012_normal_system_summary.txt"
PRESSURE_SYSTEM_SUMMARY="$RESULT_DIR/p0_012_system_pressure_system_summary.txt"
TOPIC_LIST="$RESULT_DIR/p0_012_topic_list_typed.txt"
HEALTH_TOPIC_INFO="$RESULT_DIR/p0_012_health_topic_info_verbose.txt"
SYSTEM_TOPIC_INFO="$RESULT_DIR/p0_012_system_topic_info_verbose.txt"

COLCON_STATUS="not_run"
COLCON_TEST_STATUS="not_run"
VERDICT="PASS"
BLOCKER="-"
ACTIVE_FAKE_PID=""
ACTIVE_PROCESSOR_PID=""
ACTIVE_SYSTEM_PID=""
ACTIVE_HEALTH_PID=""

NORMAL_STATE=""
PRESSURE_STATE=""
NORMAL_REASON=""
PRESSURE_REASON=""
NORMAL_RULES=""
PRESSURE_RULES=""
NORMAL_SYSTEM_MESSAGES=""
PRESSURE_SYSTEM_MESSAGES=""
NORMAL_DISK_USED_PERCENT=""
PRESSURE_DISK_USED_PERCENT=""

WARMUP_SECONDS=8
CAPTURE_SECONDS=7
CLEANUP_INT_WAIT_SECONDS=8
CLEANUP_TERM_WAIT_SECONDS=5

mkdir -p "$ARTIFACT_DIR" "$LOG_DIR" "$TEGRALOG_DIR" "$RESULT_DIR"

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
  stop_background_process "${ACTIVE_HEALTH_PID:-}" "health monitor launch"
  ACTIVE_HEALTH_PID=""

  stop_background_process "${ACTIVE_SYSTEM_PID:-}" "system metrics launch"
  ACTIVE_SYSTEM_PID=""

  stop_background_process "${ACTIVE_PROCESSOR_PID:-}" "processor launch"
  ACTIVE_PROCESSOR_PID=""

  stop_background_process "${ACTIVE_FAKE_PID:-}" "fake sensor launch"
  ACTIVE_FAKE_PID=""
}

print_head() {
  local file="$1"
  if [[ -f "$file" ]]; then
    sed -n '1,16p' "$file"
  else
    echo "(missing $file)"
  fi
}

print_tail() {
  local file="$1"
  if [[ -f "$file" ]]; then
    tail -n 16 "$file"
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

capture_health_summary() {
  local output_file="$1"
  local sample_seconds="${2:-7.0}"

  python3 - "$HEALTH_TOPIC" "$sample_seconds" <<'PY' | tee "$output_file"
import sys
import time

import rclpy
from edge_reliability_msgs.msg import HealthState
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


class HealthProbe(Node):
    def __init__(self):
        super().__init__("p0_012_health_probe")
        qos = QoSProfile(
            history=QoSHistoryPolicy.KEEP_LAST,
            depth=10,
            reliability=QoSReliabilityPolicy.RELIABLE,
            durability=QoSDurabilityPolicy.VOLATILE,
        )
        self.create_subscription(HealthState, topic, self.on_health, qos)

    def on_health(self, message):
        messages.append(message)


def state_name(state):
    if state == HealthState.HEALTHY:
        return "HEALTHY"
    if state == HealthState.WARNING:
        return "WARNING"
    if state == HealthState.UNHEALTHY:
        return "UNHEALTHY"
    return "UNKNOWN"


rclpy.init()
node = HealthProbe()
deadline = time.monotonic() + sample_seconds

try:
    while time.monotonic() < deadline:
        rclpy.spin_once(node, timeout_sec=0.1)
finally:
    node.destroy_node()
    rclpy.shutdown()

print(f"health_messages: {len(messages)}")
if not messages:
    sys.exit(2)

last = messages[-1]
print(f"last_state_code: {last.state}")
print(f"last_state_name: {state_name(last.state)}")
print(f"last_reason: {last.reason}")
print(f"last_active_rules: {','.join(last.active_rules)}")
PY
}

capture_system_metrics_summary() {
  local output_file="$1"
  local sample_seconds="${2:-7.0}"

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
        super().__init__("p0_012_system_probe")
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
print(f"last_disk_used_mb: {last.disk_used_mb:.3f}")
print(f"last_disk_total_mb: {last.disk_total_mb:.3f}")
print(f"last_disk_used_percent: {last.disk_used_percent:.3f}")
print(f"last_gpu_percent: {last.gpu_percent:.3f}")
print(f"last_temperature_c: {last.temperature_c:.3f}")
print(f"last_power_w: {last.power_w:.3f}")
print(f"last_source: {last.source}")
PY
}

launch_and_check() {
  local command_label="$1"
  local log_file="$2"
  local process_file="$3"
  shift 3

  "$@" > "$log_file" 2>&1 &
  local pid="$!"
  sleep 3

  if ! kill -0 "$pid" 2>/dev/null; then
    ps -p "$pid" -o pid,cmd > "$process_file" 2>&1 || true
    fail "$command_label exited early"
  fi

  ps -p "$pid" -o pid,cmd > "$process_file"
  echo "$pid"
}

run_system_health_scenario() {
  local scenario="$1"
  local health_config="$2"
  local health_summary="$3"
  local system_summary="$4"
  local raw_log="$TEGRALOG_DIR/p0_012_${scenario}_system_metrics_raw.log"

  local fake_log="$LOG_DIR/p0_012_${scenario}_fake_sensor_launch.txt"
  local processor_log="$LOG_DIR/p0_012_${scenario}_processor_launch.txt"
  local system_log="$LOG_DIR/p0_012_${scenario}_system_metrics_launch.txt"
  local health_log="$LOG_DIR/p0_012_${scenario}_health_monitor_launch.txt"
  local fake_process="$RESULT_DIR/p0_012_${scenario}_fake_launch_process.txt"
  local processor_process="$RESULT_DIR/p0_012_${scenario}_processor_launch_process.txt"
  local system_process="$RESULT_DIR/p0_012_${scenario}_system_launch_process.txt"
  local health_process="$RESULT_DIR/p0_012_${scenario}_health_launch_process.txt"

  : > "$raw_log"

  ACTIVE_FAKE_PID="$(launch_and_check "$scenario fake sensor launch" "$fake_log" "$fake_process" \
    ros2 launch edge_reliability_fake_sensor fake_sensor.launch.py "config_file:=$FAKE_CONFIG")"
  ACTIVE_PROCESSOR_PID="$(launch_and_check "$scenario processor launch" "$processor_log" "$processor_process" \
    ros2 launch edge_reliability_processor processor.launch.py "config_file:=$PROCESSOR_CONFIG")"
  ACTIVE_SYSTEM_PID="$(launch_and_check "$scenario system metrics launch" "$system_log" "$system_process" \
    ros2 launch edge_reliability_system system_metrics.launch.py \
      "sample_file:=$SYSTEM_SAMPLE_FILE" "raw_log_path:=$raw_log" "disk_path:=$REPO_ROOT")"
  ACTIVE_HEALTH_PID="$(launch_and_check "$scenario health monitor launch" "$health_log" "$health_process" \
    ros2 launch edge_reliability_health health_monitor.launch.py "config_file:=$health_config")"

  sleep "$WARMUP_SECONDS"

  ros2 topic list -t | tee "$TOPIC_LIST" >/dev/null
  ros2 topic info "$HEALTH_TOPIC" -v | tee "$HEALTH_TOPIC_INFO" >/dev/null
  ros2 topic info "$SYSTEM_TOPIC" -v | tee "$SYSTEM_TOPIC_INFO" >/dev/null

  capture_system_metrics_summary "$system_summary" "$CAPTURE_SECONDS"
  if [[ "$?" -ne 0 ]]; then
    fail "$scenario system metrics capture failed"
  fi

  capture_health_summary "$health_summary" "$CAPTURE_SECONDS"
  if [[ "$?" -ne 0 ]]; then
    fail "$scenario health capture failed"
  fi

  if ! grep -F "event=startup" "$system_log" >/dev/null 2>&1; then
    fail "$scenario system metrics startup log missing"
  fi
  if ! grep -F "event=first_publish" "$system_log" >/dev/null 2>&1; then
    fail "$scenario system metrics first publish log missing"
  fi
  if ! grep -F "event=startup" "$health_log" >/dev/null 2>&1; then
    fail "$scenario health monitor startup log missing"
  fi
  if ! grep -F "event=first_system_metrics_receive" "$health_log" >/dev/null 2>&1; then
    fail "$scenario health monitor system metrics receive log missing"
  fi
  if ! grep -F "event=first_health_publish" "$health_log" >/dev/null 2>&1; then
    fail "$scenario health monitor first publish log missing"
  fi

  cleanup_launches
  sleep 2
}

write_report() {
  mkdir -p "$RESULT_DIR"
  {
    echo "P0-012_RESULT"
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
    echo "health test-result tail:"
    print_tail "$HEALTH_TEST_RESULT_LOG"
    echo "system test-result tail:"
    print_tail "$SYSTEM_TEST_RESULT_LOG"
    echo
    echo "Topic Evidence"
    echo "topic list:"
    print_head "$TOPIC_LIST"
    echo "health topic info:"
    print_head "$HEALTH_TOPIC_INFO"
    echo "system topic info:"
    print_head "$SYSTEM_TOPIC_INFO"
    echo
    echo "Normal System Health"
    echo "normal system metrics summary:"
    print_head "$NORMAL_SYSTEM_SUMMARY"
    echo "normal health summary:"
    print_head "$NORMAL_HEALTH_SUMMARY"
    echo "normal state: ${NORMAL_STATE:-unknown}"
    echo "normal reason: ${NORMAL_REASON:-unknown}"
    echo "normal active rules: ${NORMAL_RULES:-none}"
    echo "normal system messages: ${NORMAL_SYSTEM_MESSAGES:-unknown}"
    echo "normal disk used percent: ${NORMAL_DISK_USED_PERCENT:-unknown}"
    echo
    echo "System Pressure Health"
    echo "system pressure system metrics summary:"
    print_head "$PRESSURE_SYSTEM_SUMMARY"
    echo "system pressure health summary:"
    print_head "$PRESSURE_HEALTH_SUMMARY"
    echo "system pressure state: ${PRESSURE_STATE:-unknown}"
    echo "system pressure reason: ${PRESSURE_REASON:-unknown}"
    echo "system pressure active rules: ${PRESSURE_RULES:-unknown}"
    echo "system pressure system messages: ${PRESSURE_SYSTEM_MESSAGES:-unknown}"
    echo "system pressure disk used percent: ${PRESSURE_DISK_USED_PERCENT:-unknown}"
    echo
    echo "Comparison"
    echo "health topic: $HEALTH_TOPIC"
    echo "health type: $HEALTH_TYPE"
    echo "pipeline topic: $PIPELINE_TOPIC"
    echo "pipeline type: $PIPELINE_TYPE"
    echo "system topic: $SYSTEM_TOPIC"
    echo "system type: $SYSTEM_TYPE"
    echo "normal state: ${NORMAL_STATE:-unknown}"
    echo "system pressure state: ${PRESSURE_STATE:-unknown}"
    echo "required: normal HEALTHY; system pressure UNHEALTHY with system_* active rules"
    echo
    echo "Git / Runtime Hygiene"
    echo "git status:"
    print_head "$GIT_STATUS"
    echo "runtime artifact paths:"
    echo "$BUILD_LOG"
    echo "$TEST_LOG"
    echo "$HEALTH_TEST_RESULT_LOG"
    echo "$SYSTEM_TEST_RESULT_LOG"
    echo "$NORMAL_SYSTEM_SUMMARY"
    echo "$NORMAL_HEALTH_SUMMARY"
    echo "$PRESSURE_SYSTEM_SUMMARY"
    echo "$PRESSURE_HEALTH_SUMMARY"
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

colcon build --packages-select \
  edge_reliability_msgs \
  edge_reliability_fake_sensor \
  edge_reliability_processor \
  edge_reliability_system \
  edge_reliability_health \
  --symlink-install 2>&1 | tee "$BUILD_LOG"
COLCON_STATUS="${PIPESTATUS[0]}"
if [[ "$COLCON_STATUS" -ne 0 ]]; then
  fail "colcon build failed"
fi

if grep -F "package had stderr output" "$BUILD_LOG" >/dev/null 2>&1; then
  fail "colcon build reported package stderr output"
fi

colcon test --packages-select edge_reliability_processor edge_reliability_system edge_reliability_health \
  2>&1 | tee "$TEST_LOG"
COLCON_TEST_STATUS="${PIPESTATUS[0]}"
colcon test-result --verbose --test-result-base build/edge_reliability_health \
  > "$HEALTH_TEST_RESULT_LOG" 2>&1 || true
colcon test-result --verbose --test-result-base build/edge_reliability_system \
  > "$SYSTEM_TEST_RESULT_LOG" 2>&1 || true
if [[ "$COLCON_TEST_STATUS" -ne 0 ]]; then
  fail "colcon test failed"
fi

source_setup_with_nounset_disabled install/setup.bash "ros2_ws install setup"

ros2 daemon stop >/dev/null 2>&1 || true
ros2 daemon start >/dev/null 2>&1 || true
sleep 2

run_system_health_scenario \
  "normal_system" \
  "$HEALTH_CONFIG" \
  "$NORMAL_HEALTH_SUMMARY" \
  "$NORMAL_SYSTEM_SUMMARY"
run_system_health_scenario \
  "system_pressure" \
  "$PRESSURE_HEALTH_CONFIG" \
  "$PRESSURE_HEALTH_SUMMARY" \
  "$PRESSURE_SYSTEM_SUMMARY"

NORMAL_STATE="$(summary_value "last_state_name" "$NORMAL_HEALTH_SUMMARY")"
PRESSURE_STATE="$(summary_value "last_state_name" "$PRESSURE_HEALTH_SUMMARY")"
NORMAL_REASON="$(summary_value "last_reason" "$NORMAL_HEALTH_SUMMARY")"
PRESSURE_REASON="$(summary_value "last_reason" "$PRESSURE_HEALTH_SUMMARY")"
NORMAL_RULES="$(summary_value "last_active_rules" "$NORMAL_HEALTH_SUMMARY")"
PRESSURE_RULES="$(summary_value "last_active_rules" "$PRESSURE_HEALTH_SUMMARY")"
NORMAL_SYSTEM_MESSAGES="$(summary_value "system_messages" "$NORMAL_SYSTEM_SUMMARY")"
PRESSURE_SYSTEM_MESSAGES="$(summary_value "system_messages" "$PRESSURE_SYSTEM_SUMMARY")"
NORMAL_DISK_USED_PERCENT="$(summary_value "last_disk_used_percent" "$NORMAL_SYSTEM_SUMMARY")"
PRESSURE_DISK_USED_PERCENT="$(summary_value "last_disk_used_percent" "$PRESSURE_SYSTEM_SUMMARY")"

if [[ "$NORMAL_STATE" != "HEALTHY" ]]; then
  fail "normal system-health scenario did not stay HEALTHY: $NORMAL_STATE"
fi

if [[ "$PRESSURE_STATE" != "UNHEALTHY" ]]; then
  fail "system pressure scenario did not become UNHEALTHY: $PRESSURE_STATE"
fi

if [[ "$PRESSURE_RULES" != *"system_"* ]]; then
  fail "system pressure active rules missing system_* rule: $PRESSURE_RULES"
fi

if [[ "$PRESSURE_RULES" != *"system_temperature_unhealthy"* && "$PRESSURE_RULES" != *"system_power_unhealthy"* ]]; then
  fail "system pressure active rules missing temperature or power unhealthy rule: $PRESSURE_RULES"
fi

awk -v count="$NORMAL_SYSTEM_MESSAGES" 'BEGIN { exit !(count >= 3) }'
if [[ "$?" -ne 0 ]]; then
  fail "normal system metrics message count too low: $NORMAL_SYSTEM_MESSAGES"
fi

awk -v count="$PRESSURE_SYSTEM_MESSAGES" 'BEGIN { exit !(count >= 3) }'
if [[ "$?" -ne 0 ]]; then
  fail "system pressure metrics message count too low: $PRESSURE_SYSTEM_MESSAGES"
fi

awk -v disk="$NORMAL_DISK_USED_PERCENT" 'BEGIN { exit !(disk >= 0) }'
if [[ "$?" -ne 0 ]]; then
  fail "normal disk used percent invalid: $NORMAL_DISK_USED_PERCENT"
fi

collect_git_status
write_report
