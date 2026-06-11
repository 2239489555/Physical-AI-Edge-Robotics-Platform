#!/usr/bin/env bash
set -uo pipefail

# Records a raw sensor bag, replays it into the processor, and compares replay metrics.
# Runtime outputs stay under runtime/bags/p0-008, runtime/results, and runtime/logs.
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
RUNTIME_DIR="$REPO_ROOT/runtime"
ARTIFACT_DIR="$RUNTIME_DIR/artifacts/preflight"
LOG_DIR="$RUNTIME_DIR/logs"
RESULT_DIR="$RUNTIME_DIR/results"
BAG_PARENT="$RUNTIME_DIR/bags/p0-008"
SCENARIO="${P0_008_SCENARIO:-normal_replay}"
RUN_STAMP="$(date -u +%Y%m%dT%H%M%SZ)"

SENSOR_TOPIC="/edge/sensors/fake_primary"
METRICS_TOPIC="/edge/metrics/pipeline"
SENSOR_TYPE="edge_reliability_msgs/msg/SensorSample"
METRICS_TYPE="edge_reliability_msgs/msg/PipelineMetrics"

BUILD_LOG="$ARTIFACT_DIR/p0_008_colcon_build.txt"
TEST_LOG="$ARTIFACT_DIR/p0_008_colcon_test.txt"
TEST_RESULT_LOG="$ARTIFACT_DIR/p0_008_colcon_test_result.txt"
FAKE_LAUNCH_LOG="$LOG_DIR/p0_008_fake_sensor_launch.txt"
PROCESSOR_LAUNCH_LOG="$LOG_DIR/p0_008_processor_launch.txt"
BAG_RECORD_LOG="$LOG_DIR/p0_008_bag_record.txt"
BAG_PLAY_LOG="$LOG_DIR/p0_008_bag_play.txt"
FAKE_LAUNCH_PROCESS="$RESULT_DIR/p0_008_fake_launch_process.txt"
PROCESSOR_LAUNCH_PROCESS="$RESULT_DIR/p0_008_processor_launch_process.txt"
RECORDED_BAG_INFO="$RESULT_DIR/p0_008_recorded_bag_info.txt"
REPLAY_METRICS_SUMMARY="$RESULT_DIR/p0_008_replay_metrics_summary.txt"
GIT_STATUS="$RESULT_DIR/p0_008_git_status.txt"
REPORT="$RESULT_DIR/p0_008_smoke_report.txt"

COLCON_STATUS="not_run"
COLCON_TEST_STATUS="not_run"
FAKE_LAUNCH_PID=""
PROCESSOR_LAUNCH_PID=""
FAKE_LAUNCH_PID_REPORTED=""
PROCESSOR_LAUNCH_PID_REPORTED=""
METRICS_CAPTURE_PID=""
VERDICT="PASS"
BLOCKER="-"
RECORDED_SENSOR_MESSAGES=""
REPLAY_METRICS_MESSAGES=""
REPLAY_RECEIVED_COUNT=""
REPLAY_EXPECTED_COUNT=""
REPLAY_DROPPED_COUNT=""
REPLAY_OUT_OF_ORDER_COUNT=""
REPLAY_RECEIVE_RATE_HZ=""
REPLAY_DROP_RATE=""
REPLAY_RECEIVE_RATIO=""
RECORD_SECONDS=8
REPLAY_CAPTURE_SECONDS=12
CLEANUP_INT_WAIT_SECONDS=8
CLEANUP_TERM_WAIT_SECONDS=5

sanitize_scenario_name() {
  local raw_name="$1"
  local sanitized
  sanitized="$(printf '%s' "$raw_name" | tr -c 'A-Za-z0-9_.-' '_' | sed -E 's/^_+//; s/_+$//')"
  if [[ -z "$sanitized" ]]; then
    sanitized="normal_replay"
  fi
  printf '%s' "$sanitized"
}

SCENARIO="$(sanitize_scenario_name "$SCENARIO")"
BAG_DIR="$BAG_PARENT/${SCENARIO}_${RUN_STAMP}"

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
  if ! kill -0 "$pid" 2>/dev/null; then
    wait "$pid" 2>/dev/null || true
    return 0
  fi

  echo "[cleanup] $label still appears alive after SIGKILL: pid=$pid" >&2
}

cleanup_launches() {
  if [[ -n "${METRICS_CAPTURE_PID:-}" ]] && kill -0 "$METRICS_CAPTURE_PID" 2>/dev/null; then
    kill -INT "$METRICS_CAPTURE_PID" 2>/dev/null || true
    wait "$METRICS_CAPTURE_PID" 2>/dev/null || true
  fi
  METRICS_CAPTURE_PID=""

  stop_background_process "${PROCESSOR_LAUNCH_PID:-}" "processor launch"
  PROCESSOR_LAUNCH_PID=""

  stop_background_process "${FAKE_LAUNCH_PID:-}" "fake sensor launch"
  FAKE_LAUNCH_PID=""
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

  # ROS 2 setup scripts may read optional variables while nounset is active.
  set +u
  # shellcheck source=/dev/null
  source "$setup_file"
  source_status="$?"
  set -u

  if [[ "$source_status" -ne 0 ]]; then
    fail "failed to source $label"
  fi
}

extract_topic_count_from_bag_info() {
  local topic="$1"
  local info_file="$2"

  awk -v topic="$topic" '
    index($0, "Topic: " topic) {
      for (i = 1; i <= NF; i++) {
        if ($i == "Count:") {
          print $(i + 1)
          exit
        }
      }
    }
  ' "$info_file"
}

capture_replay_metrics() {
  local topic="$1"
  local output_file="$2"
  local sample_seconds="${3:-12.0}"

  python3 - "$topic" "$sample_seconds" <<'PY' | tee "$output_file"
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


class ReplayMetricsProbe(Node):
    def __init__(self):
        super().__init__("p0_008_replay_metrics_probe")
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
node = ReplayMetricsProbe()
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

first = messages[0]
last = messages[-1]

print(f"first_received_count: {first.received_count}")
print(f"last_received_count: {last.received_count}")
print(f"last_expected_count: {last.expected_count}")
print(f"last_dropped_count: {last.dropped_count}")
print(f"last_out_of_order_count: {last.out_of_order_count}")
print(f"last_receive_rate_hz: {last.receive_rate_hz:.3f}")
print(f"last_expected_rate_hz: {last.expected_rate_hz:.3f}")
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

write_report() {
  mkdir -p "$RESULT_DIR"
  {
    echo "P0-008_RESULT"
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
    echo "Record"
    echo "scenario: $SCENARIO"
    echo "recorded topic: $SENSOR_TOPIC"
    echo "recorded type: $SENSOR_TYPE"
    echo "bag directory: $BAG_DIR"
    echo "record seconds: $RECORD_SECONDS"
    echo "fake sensor launch pid: ${FAKE_LAUNCH_PID_REPORTED:-stopped}"
    echo "fake sensor launch process:"
    print_head "$FAKE_LAUNCH_PROCESS"
    echo "bag record tail:"
    print_tail "$BAG_RECORD_LOG"
    echo "recorded bag info:"
    print_head "$RECORDED_BAG_INFO"
    echo "recorded sensor messages: ${RECORDED_SENSOR_MESSAGES:-unknown}"
    echo
    echo "Replay"
    echo "processor launch pid: ${PROCESSOR_LAUNCH_PID_REPORTED:-stopped}"
    echo "processor launch process:"
    print_head "$PROCESSOR_LAUNCH_PROCESS"
    echo "processor launch log head:"
    print_head "$PROCESSOR_LAUNCH_LOG"
    echo "bag play tail:"
    print_tail "$BAG_PLAY_LOG"
    echo "replay metrics summary:"
    print_head "$REPLAY_METRICS_SUMMARY"
    echo
    echo "Metrics Comparison"
    echo "recorded sensor messages: ${RECORDED_SENSOR_MESSAGES:-unknown}"
    echo "replay metrics messages: ${REPLAY_METRICS_MESSAGES:-unknown}"
    echo "replay received count: ${REPLAY_RECEIVED_COUNT:-unknown}"
    echo "replay expected count: ${REPLAY_EXPECTED_COUNT:-unknown}"
    echo "replay receive ratio: ${REPLAY_RECEIVE_RATIO:-unknown}"
    echo "replay receive rate hz: ${REPLAY_RECEIVE_RATE_HZ:-unknown}"
    echo "replay drop rate: ${REPLAY_DROP_RATE:-unknown}"
    echo "replay out_of_order count: ${REPLAY_OUT_OF_ORDER_COUNT:-unknown}"
    echo "tolerance: replay received count must be >= 90% of recorded sensor messages and <= recorded + 5; drop_rate <= 0.05; out_of_order_count == 0"
    echo
    echo "Git / Runtime Hygiene"
    echo "git status:"
    print_head "$GIT_STATUS"
    echo "runtime artifact paths:"
    echo "$BUILD_LOG"
    echo "$TEST_LOG"
    echo "$TEST_RESULT_LOG"
    echo "$FAKE_LAUNCH_LOG"
    echo "$PROCESSOR_LAUNCH_LOG"
    echo "$BAG_RECORD_LOG"
    echo "$BAG_PLAY_LOG"
    echo "$FAKE_LAUNCH_PROCESS"
    echo "$PROCESSOR_LAUNCH_PROCESS"
    echo "$RECORDED_BAG_INFO"
    echo "$REPLAY_METRICS_SUMMARY"
    echo "$BAG_DIR"
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

ros2 launch edge_reliability_fake_sensor fake_sensor.launch.py > "$FAKE_LAUNCH_LOG" 2>&1 &
FAKE_LAUNCH_PID="$!"
FAKE_LAUNCH_PID_REPORTED="$FAKE_LAUNCH_PID"
sleep 4

if ! kill -0 "$FAKE_LAUNCH_PID" 2>/dev/null; then
  ps -p "$FAKE_LAUNCH_PID" -o pid,cmd > "$FAKE_LAUNCH_PROCESS" 2>&1 || true
  fail "fake sensor launch exited early"
fi

ps -p "$FAKE_LAUNCH_PID" -o pid,cmd | tee "$FAKE_LAUNCH_PROCESS"

timeout --signal=INT "${RECORD_SECONDS}s" ros2 bag record "$SENSOR_TOPIC" -o "$BAG_DIR" > "$BAG_RECORD_LOG" 2>&1

ros2 bag info "$BAG_DIR" | tee "$RECORDED_BAG_INFO"
if [[ "${PIPESTATUS[0]}" -ne 0 ]]; then
  fail "ros2 bag info failed for recorded bag"
fi

if ! grep -F "Topic: $SENSOR_TOPIC" "$RECORDED_BAG_INFO" >/dev/null 2>&1; then
  fail "recorded bag does not include $SENSOR_TOPIC"
fi

RECORDED_SENSOR_MESSAGES="$(extract_topic_count_from_bag_info "$SENSOR_TOPIC" "$RECORDED_BAG_INFO")"
if [[ -z "$RECORDED_SENSOR_MESSAGES" ]] || [[ "$RECORDED_SENSOR_MESSAGES" -le 0 ]]; then
  fail "recorded bag contains no sensor messages"
fi

stop_background_process "$FAKE_LAUNCH_PID" "fake sensor launch"
FAKE_LAUNCH_PID=""
sleep 2

ros2 launch edge_reliability_processor processor.launch.py > "$PROCESSOR_LAUNCH_LOG" 2>&1 &
PROCESSOR_LAUNCH_PID="$!"
PROCESSOR_LAUNCH_PID_REPORTED="$PROCESSOR_LAUNCH_PID"
sleep 3

if ! kill -0 "$PROCESSOR_LAUNCH_PID" 2>/dev/null; then
  ps -p "$PROCESSOR_LAUNCH_PID" -o pid,cmd > "$PROCESSOR_LAUNCH_PROCESS" 2>&1 || true
  fail "processor launch exited early"
fi

ps -p "$PROCESSOR_LAUNCH_PID" -o pid,cmd | tee "$PROCESSOR_LAUNCH_PROCESS"

capture_replay_metrics "$METRICS_TOPIC" "$REPLAY_METRICS_SUMMARY" "$REPLAY_CAPTURE_SECONDS" &
METRICS_CAPTURE_PID="$!"
sleep 2

ros2 bag play "$BAG_DIR" > "$BAG_PLAY_LOG" 2>&1
if [[ "$?" -ne 0 ]]; then
  fail "ros2 bag play failed"
fi

wait "$METRICS_CAPTURE_PID"
if [[ "$?" -ne 0 ]]; then
  fail "replay metrics capture failed"
fi
METRICS_CAPTURE_PID=""

REPLAY_METRICS_MESSAGES="$(summary_value "metrics_messages" "$REPLAY_METRICS_SUMMARY")"
REPLAY_RECEIVED_COUNT="$(summary_value "last_received_count" "$REPLAY_METRICS_SUMMARY")"
REPLAY_EXPECTED_COUNT="$(summary_value "last_expected_count" "$REPLAY_METRICS_SUMMARY")"
REPLAY_DROPPED_COUNT="$(summary_value "last_dropped_count" "$REPLAY_METRICS_SUMMARY")"
REPLAY_OUT_OF_ORDER_COUNT="$(summary_value "last_out_of_order_count" "$REPLAY_METRICS_SUMMARY")"
REPLAY_RECEIVE_RATE_HZ="$(summary_value "last_receive_rate_hz" "$REPLAY_METRICS_SUMMARY")"
REPLAY_DROP_RATE="$(summary_value "last_drop_rate" "$REPLAY_METRICS_SUMMARY")"
REPLAY_RECEIVE_RATIO="$(awk -v received="$REPLAY_RECEIVED_COUNT" -v recorded="$RECORDED_SENSOR_MESSAGES" 'BEGIN { if (recorded <= 0) { print "0.000" } else { printf "%.3f", received / recorded } }')"

if [[ -z "$REPLAY_METRICS_MESSAGES" ]] || [[ "$REPLAY_METRICS_MESSAGES" -le 0 ]]; then
  fail "replay produced no PipelineMetrics messages"
fi

awk -v received="$REPLAY_RECEIVED_COUNT" -v recorded="$RECORDED_SENSOR_MESSAGES" \
  'BEGIN { exit !(recorded > 0 && received >= recorded * 0.90 && received <= recorded + 5) }'
if [[ "$?" -ne 0 ]]; then
  fail "replay received_count outside tolerance: received=$REPLAY_RECEIVED_COUNT recorded=$RECORDED_SENSOR_MESSAGES"
fi

awk -v rate="$REPLAY_RECEIVE_RATE_HZ" 'BEGIN { exit !(rate >= 80.0 && rate <= 130.0) }'
if [[ "$?" -ne 0 ]]; then
  fail "replay receive_rate_hz outside 80-130Hz: $REPLAY_RECEIVE_RATE_HZ"
fi

awk -v drop_rate="$REPLAY_DROP_RATE" 'BEGIN { exit !(drop_rate >= 0.0 && drop_rate <= 0.05) }'
if [[ "$?" -ne 0 ]]; then
  fail "replay drop_rate above tolerance: $REPLAY_DROP_RATE"
fi

if [[ -z "$REPLAY_OUT_OF_ORDER_COUNT" ]] || [[ "$REPLAY_OUT_OF_ORDER_COUNT" -ne 0 ]]; then
  fail "replay out_of_order_count is not zero: $REPLAY_OUT_OF_ORDER_COUNT"
fi

cleanup_launches
collect_git_status
write_report
