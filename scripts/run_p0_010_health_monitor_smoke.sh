#!/usr/bin/env bash
set -uo pipefail

# Runs normal, drop-fault, and subscriber-delay scenarios through health_monitor.
# Runtime outputs stay under runtime/results, runtime/logs, and runtime/artifacts/preflight.
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
RUNTIME_DIR="$REPO_ROOT/runtime"
ARTIFACT_DIR="$RUNTIME_DIR/artifacts/preflight"
LOG_DIR="$RUNTIME_DIR/logs"
RESULT_DIR="$RUNTIME_DIR/results"

SCENARIO_NORMAL="normal"
SCENARIO_DROP="drop_fault"
SCENARIO_DELAY="subscriber_delay"

HEALTH_TOPIC="/edge/health/state"
HEALTH_TYPE="edge_reliability_msgs/msg/HealthState"
METRICS_TOPIC="/edge/metrics/pipeline"
METRICS_TYPE="edge_reliability_msgs/msg/PipelineMetrics"

NORMAL_FAKE_CONFIG="$REPO_ROOT/ros2_ws/src/edge_reliability_fake_sensor/config/fake_sensor.yaml"
DROP_FAKE_CONFIG="$REPO_ROOT/ros2_ws/src/edge_reliability_fake_sensor/config/fake_sensor_drop.yaml"
NORMAL_PROCESSOR_CONFIG="$REPO_ROOT/ros2_ws/src/edge_reliability_processor/config/processor.yaml"
DELAY_PROCESSOR_CONFIG="$REPO_ROOT/ros2_ws/src/edge_reliability_processor/config/processor_delay.yaml"
HEALTH_CONFIG="$REPO_ROOT/ros2_ws/src/edge_reliability_health/config/health_monitor.yaml"

BUILD_LOG="$ARTIFACT_DIR/p0_010_colcon_build.txt"
TEST_LOG="$ARTIFACT_DIR/p0_010_colcon_test.txt"
TEST_RESULT_LOG="$ARTIFACT_DIR/p0_010_colcon_test_result.txt"
GIT_STATUS="$RESULT_DIR/p0_010_git_status.txt"
REPORT="$RESULT_DIR/p0_010_smoke_report.txt"

NORMAL_SUMMARY="$RESULT_DIR/p0_010_normal_health_summary.txt"
DROP_SUMMARY="$RESULT_DIR/p0_010_drop_fault_health_summary.txt"
DELAY_SUMMARY="$RESULT_DIR/p0_010_delay_fault_health_summary.txt"

COLCON_STATUS="not_run"
COLCON_TEST_STATUS="not_run"
VERDICT="PASS"
BLOCKER="-"
ACTIVE_FAKE_PID=""
ACTIVE_PROCESSOR_PID=""
ACTIVE_HEALTH_PID=""

NORMAL_STATE=""
DROP_FAULT_STATE=""
DELAY_FAULT_STATE=""
NORMAL_REASON=""
DROP_FAULT_REASON=""
DELAY_FAULT_REASON=""
NORMAL_RULES=""
DROP_FAULT_RULES=""
DELAY_FAULT_RULES=""

WARMUP_SECONDS=7
CAPTURE_SECONDS=8
CLEANUP_INT_WAIT_SECONDS=8
CLEANUP_TERM_WAIT_SECONDS=5

mkdir -p "$ARTIFACT_DIR" "$LOG_DIR" "$RESULT_DIR"

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

  stop_background_process "${ACTIVE_PROCESSOR_PID:-}" "processor launch"
  ACTIVE_PROCESSOR_PID=""

  stop_background_process "${ACTIVE_FAKE_PID:-}" "fake sensor launch"
  ACTIVE_FAKE_PID=""
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

capture_health_summary() {
  local output_file="$1"
  local sample_seconds="${2:-8.0}"

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
        super().__init__("p0_010_health_probe")
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

run_health_scenario() {
  local scenario="$1"
  local fake_config="$2"
  local processor_config="$3"
  local summary_file="$4"

  local fake_log="$LOG_DIR/p0_010_${scenario}_fake_sensor_launch.txt"
  local processor_log="$LOG_DIR/p0_010_${scenario}_processor_launch.txt"
  local health_log="$LOG_DIR/p0_010_${scenario}_health_monitor_launch.txt"
  local fake_process="$RESULT_DIR/p0_010_${scenario}_fake_launch_process.txt"
  local processor_process="$RESULT_DIR/p0_010_${scenario}_processor_launch_process.txt"
  local health_process="$RESULT_DIR/p0_010_${scenario}_health_launch_process.txt"

  ACTIVE_FAKE_PID="$(launch_and_check "$scenario fake sensor launch" "$fake_log" "$fake_process" \
    ros2 launch edge_reliability_fake_sensor fake_sensor.launch.py "config_file:=$fake_config")"
  ACTIVE_PROCESSOR_PID="$(launch_and_check "$scenario processor launch" "$processor_log" "$processor_process" \
    ros2 launch edge_reliability_processor processor.launch.py "config_file:=$processor_config")"
  ACTIVE_HEALTH_PID="$(launch_and_check "$scenario health monitor launch" "$health_log" "$health_process" \
    ros2 launch edge_reliability_health health_monitor.launch.py "config_file:=$HEALTH_CONFIG")"

  sleep "$WARMUP_SECONDS"

  capture_health_summary "$summary_file" "$CAPTURE_SECONDS"
  if [[ "$?" -ne 0 ]]; then
    fail "$scenario health capture failed"
  fi

  if ! grep -F "event=startup" "$health_log" >/dev/null 2>&1; then
    fail "$scenario health monitor startup log missing"
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
    echo "P0-010_RESULT"
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
    echo "Normal Health"
    echo "normal health summary:"
    print_head "$NORMAL_SUMMARY"
    echo "normal state: ${NORMAL_STATE:-unknown}"
    echo "normal reason: ${NORMAL_REASON:-unknown}"
    echo "normal active rules: ${NORMAL_RULES:-none}"
    echo
    echo "Drop Fault Health"
    echo "drop fault health summary:"
    print_head "$DROP_SUMMARY"
    echo "drop fault state: ${DROP_FAULT_STATE:-unknown}"
    echo "drop fault reason: ${DROP_FAULT_REASON:-unknown}"
    echo "drop fault active rules: ${DROP_FAULT_RULES:-unknown}"
    echo
    echo "Delay Fault Health"
    echo "delay fault health summary:"
    print_head "$DELAY_SUMMARY"
    echo "delay fault state: ${DELAY_FAULT_STATE:-unknown}"
    echo "delay fault reason: ${DELAY_FAULT_REASON:-unknown}"
    echo "delay fault active rules: ${DELAY_FAULT_RULES:-unknown}"
    echo
    echo "Comparison"
    echo "health topic: $HEALTH_TOPIC"
    echo "health type: $HEALTH_TYPE"
    echo "metrics topic: $METRICS_TOPIC"
    echo "metrics type: $METRICS_TYPE"
    echo "normal state: ${NORMAL_STATE:-unknown}"
    echo "drop fault state: ${DROP_FAULT_STATE:-unknown}"
    echo "delay fault state: ${DELAY_FAULT_STATE:-unknown}"
    echo "required: normal HEALTHY; drop fault UNHEALTHY; delay fault WARNING or UNHEALTHY"
    echo
    echo "Git / Runtime Hygiene"
    echo "git status:"
    print_head "$GIT_STATUS"
    echo "runtime artifact paths:"
    echo "$BUILD_LOG"
    echo "$TEST_LOG"
    echo "$TEST_RESULT_LOG"
    echo "$NORMAL_SUMMARY"
    echo "$DROP_SUMMARY"
    echo "$DELAY_SUMMARY"
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

colcon build --packages-select edge_reliability_msgs edge_reliability_fake_sensor edge_reliability_processor edge_reliability_health --symlink-install \
  2>&1 | tee "$BUILD_LOG"
COLCON_STATUS="${PIPESTATUS[0]}"
if [[ "$COLCON_STATUS" -ne 0 ]]; then
  fail "colcon build failed"
fi

colcon test --packages-select edge_reliability_processor edge_reliability_health \
  2>&1 | tee "$TEST_LOG"
COLCON_TEST_STATUS="${PIPESTATUS[0]}"
colcon test-result --verbose --test-result-base build/edge_reliability_health \
  > "$TEST_RESULT_LOG" 2>&1 || true
if [[ "$COLCON_TEST_STATUS" -ne 0 ]]; then
  fail "colcon test failed"
fi

source_setup_with_nounset_disabled install/setup.bash "ros2_ws install setup"

ros2 daemon stop >/dev/null 2>&1 || true
ros2 daemon start >/dev/null 2>&1 || true
sleep 2

run_health_scenario "$SCENARIO_NORMAL" "$NORMAL_FAKE_CONFIG" "$NORMAL_PROCESSOR_CONFIG" "$NORMAL_SUMMARY"
run_health_scenario "$SCENARIO_DROP" "$DROP_FAKE_CONFIG" "$NORMAL_PROCESSOR_CONFIG" "$DROP_SUMMARY"
run_health_scenario "$SCENARIO_DELAY" "$NORMAL_FAKE_CONFIG" "$DELAY_PROCESSOR_CONFIG" "$DELAY_SUMMARY"

NORMAL_STATE="$(summary_value "last_state_name" "$NORMAL_SUMMARY")"
DROP_FAULT_STATE="$(summary_value "last_state_name" "$DROP_SUMMARY")"
DELAY_FAULT_STATE="$(summary_value "last_state_name" "$DELAY_SUMMARY")"
NORMAL_REASON="$(summary_value "last_reason" "$NORMAL_SUMMARY")"
DROP_FAULT_REASON="$(summary_value "last_reason" "$DROP_SUMMARY")"
DELAY_FAULT_REASON="$(summary_value "last_reason" "$DELAY_SUMMARY")"
NORMAL_RULES="$(summary_value "last_active_rules" "$NORMAL_SUMMARY")"
DROP_FAULT_RULES="$(summary_value "last_active_rules" "$DROP_SUMMARY")"
DELAY_FAULT_RULES="$(summary_value "last_active_rules" "$DELAY_SUMMARY")"

if [[ "$NORMAL_STATE" != "HEALTHY" ]]; then
  fail "normal scenario did not stay HEALTHY: $NORMAL_STATE"
fi

if [[ "$DROP_FAULT_STATE" != "UNHEALTHY" ]]; then
  fail "drop fault did not become UNHEALTHY: $DROP_FAULT_STATE"
fi

if [[ "$DROP_FAULT_RULES" != *"drop_rate_unhealthy"* ]]; then
  fail "drop fault health rules missing drop_rate_unhealthy: $DROP_FAULT_RULES"
fi

if [[ "$DELAY_FAULT_STATE" == "HEALTHY" ]]; then
  fail "delay fault did not leave HEALTHY state"
fi

if [[ "$DELAY_FAULT_RULES" != *"p95_latency_"* ]]; then
  fail "delay fault health rules missing p95 latency rule: $DELAY_FAULT_RULES"
fi

collect_git_status
write_report
