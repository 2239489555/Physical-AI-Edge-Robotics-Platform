#!/usr/bin/env bash
set -uo pipefail

# Runs normal, drop-fault, and subscriber-delay scenarios.
# Runtime outputs stay under runtime/bags/p0-009, runtime/results, and runtime/logs.
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
RUNTIME_DIR="$REPO_ROOT/runtime"
ARTIFACT_DIR="$RUNTIME_DIR/artifacts/preflight"
LOG_DIR="$RUNTIME_DIR/logs"
RESULT_DIR="$RUNTIME_DIR/results"
BAG_PARENT="$RUNTIME_DIR/bags/p0-009"
RUN_STAMP="$(date -u +%Y%m%dT%H%M%SZ)"

SCENARIO_NORMAL="normal"
SCENARIO_DROP="drop_fault"
SCENARIO_DELAY="subscriber_delay"

SENSOR_TOPIC="/edge/sensors/fake_primary"
METRICS_TOPIC="/edge/metrics/pipeline"
SENSOR_TYPE="edge_reliability_msgs/msg/SensorSample"
METRICS_TYPE="edge_reliability_msgs/msg/PipelineMetrics"

NORMAL_FAKE_CONFIG="$REPO_ROOT/ros2_ws/src/edge_reliability_fake_sensor/config/fake_sensor.yaml"
DROP_FAKE_CONFIG="$REPO_ROOT/ros2_ws/src/edge_reliability_fake_sensor/config/fake_sensor_drop.yaml"
NORMAL_PROCESSOR_CONFIG="$REPO_ROOT/ros2_ws/src/edge_reliability_processor/config/processor.yaml"
DELAY_PROCESSOR_CONFIG="$REPO_ROOT/ros2_ws/src/edge_reliability_processor/config/processor_delay.yaml"

BUILD_LOG="$ARTIFACT_DIR/p0_009_colcon_build.txt"
TEST_LOG="$ARTIFACT_DIR/p0_009_colcon_test.txt"
TEST_RESULT_LOG="$ARTIFACT_DIR/p0_009_colcon_test_result.txt"
GIT_STATUS="$RESULT_DIR/p0_009_git_status.txt"
REPORT="$RESULT_DIR/p0_009_smoke_report.txt"

NORMAL_SUMMARY="$RESULT_DIR/p0_009_normal_metrics_summary.txt"
DROP_SUMMARY="$RESULT_DIR/p0_009_drop_fault_metrics_summary.txt"
DELAY_SUMMARY="$RESULT_DIR/p0_009_delay_fault_metrics_summary.txt"

DROP_BAG_DIR="$BAG_PARENT/${SCENARIO_DROP}_${RUN_STAMP}"
DELAY_BAG_DIR="$BAG_PARENT/${SCENARIO_DELAY}_${RUN_STAMP}"
DROP_BAG_INFO="$RESULT_DIR/p0_009_drop_fault_bag_info.txt"
DELAY_BAG_INFO="$RESULT_DIR/p0_009_delay_fault_bag_info.txt"

COLCON_STATUS="not_run"
COLCON_TEST_STATUS="not_run"
VERDICT="PASS"
BLOCKER="-"
ACTIVE_FAKE_PID=""
ACTIVE_PROCESSOR_PID=""
ACTIVE_BAG_RECORD_PID=""

NORMAL_DROP_RATE=""
DROP_FAULT_DROP_RATE=""
DROP_RATE_INCREASE=""
NORMAL_P95_LATENCY_MS=""
DELAY_FAULT_P95_LATENCY_MS=""
P95_LATENCY_INCREASE_MS=""
DROP_FAULT_BAG_MESSAGES=""
DELAY_FAULT_BAG_MESSAGES=""

WARMUP_SECONDS=5
CAPTURE_SECONDS=10
BAG_SECONDS=10
CLEANUP_INT_WAIT_SECONDS=8
CLEANUP_TERM_WAIT_SECONDS=5

mkdir -p "$ARTIFACT_DIR" "$LOG_DIR" "$RESULT_DIR" "$BAG_PARENT"

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
  stop_background_process "${ACTIVE_BAG_RECORD_PID:-}" "bag record"
  ACTIVE_BAG_RECORD_PID=""

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

capture_metrics_summary() {
  local output_file="$1"
  local sample_seconds="${2:-10.0}"

  python3 - "$METRICS_TOPIC" "$sample_seconds" <<'PY' | tee "$output_file"
import sys
import time

import rclpy
from edge_reliability_msgs.msg import PipelineMetrics
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


class MetricsProbe(Node):
    def __init__(self):
        super().__init__("p0_009_metrics_probe")
        qos = QoSProfile(
            history=QoSHistoryPolicy.KEEP_LAST,
            depth=10,
            reliability=QoSReliabilityPolicy.RELIABLE,
            durability=QoSDurabilityPolicy.VOLATILE,
        )
        self.create_subscription(PipelineMetrics, topic, self.on_metrics, qos)

    def on_metrics(self, message):
        messages.append(message)


rclpy.init()
node = MetricsProbe()
deadline = time.monotonic() + sample_seconds

try:
    while time.monotonic() < deadline:
        rclpy.spin_once(node, timeout_sec=0.1)
finally:
    node.destroy_node()
    rclpy.shutdown()

print(f"metrics_messages: {len(messages)}")
if not messages:
    sys.exit(2)

last = messages[-1]
print(f"last_received_count: {last.received_count}")
print(f"last_expected_count: {last.expected_count}")
print(f"last_dropped_count: {last.dropped_count}")
print(f"last_out_of_order_count: {last.out_of_order_count}")
print(f"last_receive_rate_hz: {last.receive_rate_hz:.3f}")
print(f"last_average_latency_ms: {last.average_latency_ms:.3f}")
print(f"last_p95_latency_ms: {last.p95_latency_ms:.3f}")
print(f"last_p99_latency_ms: {last.p99_latency_ms:.3f}")
print(f"last_drop_rate: {last.drop_rate:.6f}")
PY
}

summary_value() {
  local key="$1"
  local file="$2"
  awk -F': ' -v key="$key" '$1 == key { value = $2 } END { print value }' "$file"
}

extract_total_messages_from_bag_info() {
  local info_file="$1"
  awk '/^Messages:/ { print $2; exit }' "$info_file"
}

record_fault_bag() {
  local bag_dir="$1"
  local bag_log="$2"

  timeout --signal=INT "${BAG_SECONDS}s" ros2 bag record "$SENSOR_TOPIC" "$METRICS_TOPIC" -o "$bag_dir" > "$bag_log" 2>&1 &
  ACTIVE_BAG_RECORD_PID="$!"
}

run_metric_scenario() {
  local scenario="$1"
  local fake_config="$2"
  local processor_config="$3"
  local summary_file="$4"
  local bag_dir="${5:-}"
  local bag_info_file="${6:-}"

  local fake_log="$LOG_DIR/p0_009_${scenario}_fake_sensor_launch.txt"
  local processor_log="$LOG_DIR/p0_009_${scenario}_processor_launch.txt"
  local fake_process="$RESULT_DIR/p0_009_${scenario}_fake_launch_process.txt"
  local processor_process="$RESULT_DIR/p0_009_${scenario}_processor_launch_process.txt"
  local bag_log="$LOG_DIR/p0_009_${scenario}_bag_record.txt"

  ros2 launch edge_reliability_fake_sensor fake_sensor.launch.py "config_file:=$fake_config" > "$fake_log" 2>&1 &
  ACTIVE_FAKE_PID="$!"
  sleep 3
  if ! kill -0 "$ACTIVE_FAKE_PID" 2>/dev/null; then
    ps -p "$ACTIVE_FAKE_PID" -o pid,cmd > "$fake_process" 2>&1 || true
    fail "$scenario fake sensor launch exited early"
  fi
  ps -p "$ACTIVE_FAKE_PID" -o pid,cmd | tee "$fake_process"

  ros2 launch edge_reliability_processor processor.launch.py "config_file:=$processor_config" > "$processor_log" 2>&1 &
  ACTIVE_PROCESSOR_PID="$!"
  sleep "$WARMUP_SECONDS"
  if ! kill -0 "$ACTIVE_PROCESSOR_PID" 2>/dev/null; then
    ps -p "$ACTIVE_PROCESSOR_PID" -o pid,cmd > "$processor_process" 2>&1 || true
    fail "$scenario processor launch exited early"
  fi
  ps -p "$ACTIVE_PROCESSOR_PID" -o pid,cmd | tee "$processor_process"

  if [[ -n "$bag_dir" ]]; then
    record_fault_bag "$bag_dir" "$bag_log"
    sleep 1
  fi

  capture_metrics_summary "$summary_file" "$CAPTURE_SECONDS"
  if [[ "$?" -ne 0 ]]; then
    fail "$scenario metrics capture failed"
  fi

  if [[ -n "${ACTIVE_BAG_RECORD_PID:-}" ]]; then
    wait "$ACTIVE_BAG_RECORD_PID" 2>/dev/null || true
    ACTIVE_BAG_RECORD_PID=""

    ros2 bag info "$bag_dir" | tee "$bag_info_file"
    if [[ "${PIPESTATUS[0]}" -ne 0 ]]; then
      fail "$scenario ros2 bag info failed"
    fi
  fi

  if ! grep -F "event=startup" "$fake_log" >/dev/null 2>&1; then
    fail "$scenario fake sensor startup log missing"
  fi
  if ! grep -F "event=startup" "$processor_log" >/dev/null 2>&1; then
    fail "$scenario processor startup log missing"
  fi

  cleanup_launches
  sleep 2
}

write_report() {
  mkdir -p "$RESULT_DIR"
  {
    echo "P0-009_RESULT"
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
    echo "Normal Scenario"
    echo "normal metrics summary:"
    print_head "$NORMAL_SUMMARY"
    echo "normal drop rate: ${NORMAL_DROP_RATE:-unknown}"
    echo "normal p95 latency ms: ${NORMAL_P95_LATENCY_MS:-unknown}"
    echo
    echo "Drop Fault Scenario"
    echo "drop fault config: fake_sensor_drop.yaml"
    echo "drop fault metrics summary:"
    print_head "$DROP_SUMMARY"
    echo "drop fault bag directory: $DROP_BAG_DIR"
    echo "drop fault bag info:"
    print_head "$DROP_BAG_INFO"
    echo "drop fault bag messages: ${DROP_FAULT_BAG_MESSAGES:-unknown}"
    echo "drop fault drop rate: ${DROP_FAULT_DROP_RATE:-unknown}"
    echo "drop rate increase: ${DROP_RATE_INCREASE:-unknown}"
    echo
    echo "Delay Fault Scenario"
    echo "delay fault config: processor_delay.yaml"
    echo "delay fault metrics summary:"
    print_head "$DELAY_SUMMARY"
    echo "delay fault bag directory: $DELAY_BAG_DIR"
    echo "delay fault bag info:"
    print_head "$DELAY_BAG_INFO"
    echo "delay fault bag messages: ${DELAY_FAULT_BAG_MESSAGES:-unknown}"
    echo "delay fault p95 latency ms: ${DELAY_FAULT_P95_LATENCY_MS:-unknown}"
    echo "p95 latency increase ms: ${P95_LATENCY_INCREASE_MS:-unknown}"
    echo
    echo "Comparison"
    echo "normal drop rate: ${NORMAL_DROP_RATE:-unknown}"
    echo "drop fault drop rate: ${DROP_FAULT_DROP_RATE:-unknown}"
    echo "drop rate increase: ${DROP_RATE_INCREASE:-unknown}"
    echo "normal p95 latency ms: ${NORMAL_P95_LATENCY_MS:-unknown}"
    echo "delay fault p95 latency ms: ${DELAY_FAULT_P95_LATENCY_MS:-unknown}"
    echo "p95 latency increase ms: ${P95_LATENCY_INCREASE_MS:-unknown}"
    echo "tolerance: drop rate increase >= 0.05; p95 latency increase >= 4.0ms; fault bags contain messages"
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
    echo "$DROP_BAG_INFO"
    echo "$DELAY_BAG_INFO"
    echo "$DROP_BAG_DIR"
    echo "$DELAY_BAG_DIR"
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

colcon build --packages-select edge_reliability_msgs edge_reliability_fake_sensor edge_reliability_processor --symlink-install \
  2>&1 | tee "$BUILD_LOG"
COLCON_STATUS="${PIPESTATUS[0]}"
if [[ "$COLCON_STATUS" -ne 0 ]]; then
  fail "colcon build failed"
fi

colcon test --packages-select edge_reliability_processor \
  2>&1 | tee "$TEST_LOG"
COLCON_TEST_STATUS="${PIPESTATUS[0]}"
colcon test-result --verbose --test-result-base build/edge_reliability_processor \
  > "$TEST_RESULT_LOG" 2>&1 || true
if [[ "$COLCON_TEST_STATUS" -ne 0 ]]; then
  fail "colcon test failed"
fi

source_setup_with_nounset_disabled install/setup.bash "ros2_ws install setup"

ros2 daemon stop >/dev/null 2>&1 || true
ros2 daemon start >/dev/null 2>&1 || true
sleep 2

run_metric_scenario "$SCENARIO_NORMAL" "$NORMAL_FAKE_CONFIG" "$NORMAL_PROCESSOR_CONFIG" "$NORMAL_SUMMARY"
run_metric_scenario "$SCENARIO_DROP" "$DROP_FAKE_CONFIG" "$NORMAL_PROCESSOR_CONFIG" "$DROP_SUMMARY" "$DROP_BAG_DIR" "$DROP_BAG_INFO"
run_metric_scenario "$SCENARIO_DELAY" "$NORMAL_FAKE_CONFIG" "$DELAY_PROCESSOR_CONFIG" "$DELAY_SUMMARY" "$DELAY_BAG_DIR" "$DELAY_BAG_INFO"

NORMAL_DROP_RATE="$(summary_value "last_drop_rate" "$NORMAL_SUMMARY")"
DROP_FAULT_DROP_RATE="$(summary_value "last_drop_rate" "$DROP_SUMMARY")"
NORMAL_P95_LATENCY_MS="$(summary_value "last_p95_latency_ms" "$NORMAL_SUMMARY")"
DELAY_FAULT_P95_LATENCY_MS="$(summary_value "last_p95_latency_ms" "$DELAY_SUMMARY")"
DROP_FAULT_BAG_MESSAGES="$(extract_total_messages_from_bag_info "$DROP_BAG_INFO")"
DELAY_FAULT_BAG_MESSAGES="$(extract_total_messages_from_bag_info "$DELAY_BAG_INFO")"

DROP_RATE_INCREASE="$(awk -v fault="$DROP_FAULT_DROP_RATE" -v normal="$NORMAL_DROP_RATE" 'BEGIN { printf "%.6f", fault - normal }')"
P95_LATENCY_INCREASE_MS="$(awk -v fault="$DELAY_FAULT_P95_LATENCY_MS" -v normal="$NORMAL_P95_LATENCY_MS" 'BEGIN { printf "%.3f", fault - normal }')"

awk -v normal="$NORMAL_DROP_RATE" 'BEGIN { exit !(normal >= 0.0 && normal <= 0.02) }'
if [[ "$?" -ne 0 ]]; then
  fail "normal drop rate outside 0-0.02: $NORMAL_DROP_RATE"
fi

awk -v fault="$DROP_FAULT_DROP_RATE" -v increase="$DROP_RATE_INCREASE" \
  'BEGIN { exit !(fault >= 0.05 && increase >= 0.05) }'
if [[ "$?" -ne 0 ]]; then
  fail "drop fault did not increase drop rate enough: normal=$NORMAL_DROP_RATE fault=$DROP_FAULT_DROP_RATE increase=$DROP_RATE_INCREASE"
fi

awk -v increase="$P95_LATENCY_INCREASE_MS" 'BEGIN { exit !(increase >= 4.0) }'
if [[ "$?" -ne 0 ]]; then
  fail "delay fault did not increase p95 latency enough: normal=$NORMAL_P95_LATENCY_MS fault=$DELAY_FAULT_P95_LATENCY_MS increase=$P95_LATENCY_INCREASE_MS"
fi

if [[ -z "$DROP_FAULT_BAG_MESSAGES" ]] || [[ "$DROP_FAULT_BAG_MESSAGES" -le 0 ]]; then
  fail "drop fault bag contains no messages"
fi

if [[ -z "$DELAY_FAULT_BAG_MESSAGES" ]] || [[ "$DELAY_FAULT_BAG_MESSAGES" -le 0 ]]; then
  fail "delay fault bag contains no messages"
fi

collect_git_status
write_report
