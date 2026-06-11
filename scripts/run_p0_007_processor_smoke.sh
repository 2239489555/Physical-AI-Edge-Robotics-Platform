#!/usr/bin/env bash
set -uo pipefail

# Writes evidence under runtime/results, runtime/logs, and runtime/bags/p0-007.
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
RUNTIME_DIR="$REPO_ROOT/runtime"
ARTIFACT_DIR="$RUNTIME_DIR/artifacts/preflight"
LOG_DIR="$RUNTIME_DIR/logs"
RESULT_DIR="$RUNTIME_DIR/results"
BAG_PARENT="$RUNTIME_DIR/bags/p0-007"
BAG_DIR="$BAG_PARENT/processor_smoke_$(date -u +%Y%m%dT%H%M%SZ)"

SENSOR_TOPIC="/edge/sensors/fake_primary"
SENSOR_TYPE="edge_reliability_msgs/msg/SensorSample"
METRICS_TOPIC="/edge/metrics/pipeline"
METRICS_TYPE="edge_reliability_msgs/msg/PipelineMetrics"

BUILD_LOG="$ARTIFACT_DIR/p0_007_colcon_build.txt"
TEST_LOG="$ARTIFACT_DIR/p0_007_colcon_test.txt"
TEST_RESULT_LOG="$ARTIFACT_DIR/p0_007_colcon_test_result.txt"
FAKE_LAUNCH_LOG="$LOG_DIR/p0_007_fake_sensor_launch.txt"
PROCESSOR_LAUNCH_LOG="$LOG_DIR/p0_007_processor_launch.txt"
BAG_RECORD_LOG="$LOG_DIR/p0_007_bag_record.txt"
FAKE_LAUNCH_PROCESS="$RESULT_DIR/p0_007_fake_launch_process.txt"
PROCESSOR_LAUNCH_PROCESS="$RESULT_DIR/p0_007_processor_launch_process.txt"
TOPIC_LIST="$RESULT_DIR/p0_007_topic_list_typed.txt"
SENSOR_TOPIC_INFO="$RESULT_DIR/p0_007_sensor_topic_info_verbose.txt"
METRICS_TOPIC_INFO="$RESULT_DIR/p0_007_metrics_topic_info_verbose.txt"
METRICS_ECHO="$RESULT_DIR/p0_007_metrics_echo_once.txt"
SENSOR_TOPIC_HZ="$RESULT_DIR/p0_007_sensor_topic_hz.txt"
METRICS_TOPIC_HZ="$RESULT_DIR/p0_007_metrics_topic_hz.txt"
BAG_INFO="$RESULT_DIR/p0_007_bag_info.txt"
GIT_STATUS="$RESULT_DIR/p0_007_git_status.txt"
REPORT="$RESULT_DIR/p0_007_smoke_report.txt"

COLCON_STATUS="not_run"
COLCON_TEST_STATUS="not_run"
FAKE_LAUNCH_PID=""
PROCESSOR_LAUNCH_PID=""
FAKE_LAUNCH_PID_REPORTED=""
PROCESSOR_LAUNCH_PID_REPORTED=""
VERDICT="PASS"
BLOCKER="-"
SENSOR_LAST_RATE=""
METRICS_LAST_RATE=""
BAG_MESSAGES=""
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
  if ! kill -0 "$pid" 2>/dev/null; then
    wait "$pid" 2>/dev/null || true
    return 0
  fi

  echo "[cleanup] $label still appears alive after SIGKILL: pid=$pid" >&2
}

cleanup_launches() {
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

measure_sensor_hz_with_best_effort() {
  local topic="$1"
  local output_file="$2"
  local sample_seconds="${3:-10.0}"

  python3 - "$topic" "$sample_seconds" <<'PY' | tee "$output_file"
import sys
import time

import rclpy
from edge_reliability_msgs.msg import SensorSample
from rclpy.node import Node
from rclpy.qos import (
    QoSDurabilityPolicy,
    QoSHistoryPolicy,
    QoSProfile,
    QoSReliabilityPolicy,
)


topic = sys.argv[1]
sample_seconds = float(sys.argv[2])
received_count = 0
first_time = None
last_time = None


class SensorHzProbe(Node):
    def __init__(self):
        super().__init__("p0_007_sensor_hz_probe")
        qos = QoSProfile(
            history=QoSHistoryPolicy.KEEP_LAST,
            depth=10,
            reliability=QoSReliabilityPolicy.BEST_EFFORT,
            durability=QoSDurabilityPolicy.VOLATILE,
        )
        self.create_subscription(SensorSample, topic, self.on_sample, qos)

    def on_sample(self, _message):
        global received_count, first_time, last_time
        now = time.monotonic()
        if first_time is None:
            first_time = now
        last_time = now
        received_count += 1


rclpy.init()
node = SensorHzProbe()
deadline = time.monotonic() + sample_seconds

try:
    while time.monotonic() < deadline:
        rclpy.spin_once(node, timeout_sec=0.1)
finally:
    node.destroy_node()
    rclpy.shutdown()

if received_count < 2 or first_time is None or last_time is None or last_time <= first_time:
    print("average rate: unavailable")
    print(f"received samples: {received_count}")
    sys.exit(2)

window_seconds = last_time - first_time
average_rate = (received_count - 1) / window_seconds
print(f"average rate: {average_rate:.3f}")
print(f"received samples: {received_count}")
print(f"measurement window: {window_seconds:.3f}s")
PY
}

measure_metrics_hz_with_reliable() {
  local topic="$1"
  local output_file="$2"
  local sample_seconds="${3:-6.0}"

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
received_count = 0
first_time = None
last_time = None


class MetricsHzProbe(Node):
    def __init__(self):
        super().__init__("p0_007_metrics_hz_probe")
        qos = QoSProfile(
            history=QoSHistoryPolicy.KEEP_LAST,
            depth=10,
            reliability=QoSReliabilityPolicy.RELIABLE,
            durability=QoSDurabilityPolicy.VOLATILE,
        )
        self.create_subscription(PipelineMetrics, topic, self.on_sample, qos)

    def on_sample(self, _message):
        global received_count, first_time, last_time
        now = time.monotonic()
        if first_time is None:
            first_time = now
        last_time = now
        received_count += 1


rclpy.init()
node = MetricsHzProbe()
deadline = time.monotonic() + sample_seconds

try:
    while time.monotonic() < deadline:
        rclpy.spin_once(node, timeout_sec=0.1)
finally:
    node.destroy_node()
    rclpy.shutdown()

if received_count < 2 or first_time is None or last_time is None or last_time <= first_time:
    print("average rate: unavailable")
    print(f"received samples: {received_count}")
    sys.exit(2)

window_seconds = last_time - first_time
average_rate = (received_count - 1) / window_seconds
print(f"average rate: {average_rate:.3f}")
print(f"received samples: {received_count}")
print(f"measurement window: {window_seconds:.3f}s")
PY
}

write_report() {
  mkdir -p "$RESULT_DIR"
  {
    echo "P0-007_RESULT"
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
    echo "Launch"
    echo "fake sensor launch pid: ${FAKE_LAUNCH_PID_REPORTED:-stopped}"
    echo "fake sensor launch process:"
    print_head "$FAKE_LAUNCH_PROCESS"
    echo "processor launch pid: ${PROCESSOR_LAUNCH_PID_REPORTED:-stopped}"
    echo "processor launch process:"
    print_head "$PROCESSOR_LAUNCH_PROCESS"
    echo "fake sensor launch log head:"
    print_head "$FAKE_LAUNCH_LOG"
    echo "processor launch log head:"
    print_head "$PROCESSOR_LAUNCH_LOG"
    echo "processor launch log tail:"
    print_tail "$PROCESSOR_LAUNCH_LOG"
    echo
    echo "Topic Evidence"
    echo "typed topic list:"
    print_head "$TOPIC_LIST"
    echo "sensor topic info:"
    print_head "$SENSOR_TOPIC_INFO"
    echo "metrics topic info:"
    print_head "$METRICS_TOPIC_INFO"
    echo "metrics echo once:"
    print_head "$METRICS_ECHO"
    echo "sensor topic hz:"
    print_tail "$SENSOR_TOPIC_HZ"
    echo "sensor last average rate: ${SENSOR_LAST_RATE:-unknown}"
    echo "metrics topic hz:"
    print_tail "$METRICS_TOPIC_HZ"
    echo "metrics last average rate: ${METRICS_LAST_RATE:-unknown}"
    echo
    echo "Rosbag Evidence"
    echo "bag directory: $BAG_DIR"
    echo "bag record tail:"
    print_tail "$BAG_RECORD_LOG"
    echo "bag info:"
    print_head "$BAG_INFO"
    echo "bag messages: ${BAG_MESSAGES:-unknown}"
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
    echo "$FAKE_LAUNCH_PROCESS"
    echo "$PROCESSOR_LAUNCH_PROCESS"
    echo "$TOPIC_LIST"
    echo "$SENSOR_TOPIC_INFO"
    echo "$METRICS_TOPIC_INFO"
    echo "$METRICS_ECHO"
    echo "$SENSOR_TOPIC_HZ"
    echo "$METRICS_TOPIC_HZ"
    echo "$BAG_RECORD_LOG"
    echo "$BAG_INFO"
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
sleep 3

if ! kill -0 "$FAKE_LAUNCH_PID" 2>/dev/null; then
  ps -p "$FAKE_LAUNCH_PID" -o pid,cmd > "$FAKE_LAUNCH_PROCESS" 2>&1 || true
  fail "fake sensor launch exited early"
fi

ros2 launch edge_reliability_processor processor.launch.py > "$PROCESSOR_LAUNCH_LOG" 2>&1 &
PROCESSOR_LAUNCH_PID="$!"
PROCESSOR_LAUNCH_PID_REPORTED="$PROCESSOR_LAUNCH_PID"
sleep 5

if ! kill -0 "$PROCESSOR_LAUNCH_PID" 2>/dev/null; then
  ps -p "$PROCESSOR_LAUNCH_PID" -o pid,cmd > "$PROCESSOR_LAUNCH_PROCESS" 2>&1 || true
  fail "processor launch exited early"
fi

ps -p "$FAKE_LAUNCH_PID" -o pid,cmd | tee "$FAKE_LAUNCH_PROCESS"
ps -p "$PROCESSOR_LAUNCH_PID" -o pid,cmd | tee "$PROCESSOR_LAUNCH_PROCESS"

ros2 topic list -t | tee "$TOPIC_LIST"
if [[ "${PIPESTATUS[0]}" -ne 0 ]]; then
  fail "ros2 topic list failed"
fi

ros2 topic info "$SENSOR_TOPIC" -v | tee "$SENSOR_TOPIC_INFO"
if [[ "${PIPESTATUS[0]}" -ne 0 ]]; then
  fail "ros2 topic info failed for sensor topic"
fi

ros2 topic info "$METRICS_TOPIC" -v | tee "$METRICS_TOPIC_INFO"
if [[ "${PIPESTATUS[0]}" -ne 0 ]]; then
  fail "ros2 topic info failed for metrics topic"
fi

if ! grep -F "Type: $SENSOR_TYPE" "$SENSOR_TOPIC_INFO" >/dev/null 2>&1; then
  fail "sensor topic info does not report type $SENSOR_TYPE"
fi

if ! grep -F "Node name: fake_sensor_adapter" "$SENSOR_TOPIC_INFO" >/dev/null 2>&1; then
  fail "sensor topic info does not show fake_sensor_adapter as publisher"
fi

if ! grep -F "Node name: sensor_processor" "$SENSOR_TOPIC_INFO" >/dev/null 2>&1; then
  fail "sensor topic info does not show sensor_processor as subscriber"
fi

if ! grep -F "Type: $METRICS_TYPE" "$METRICS_TOPIC_INFO" >/dev/null 2>&1; then
  fail "metrics topic info does not report type $METRICS_TYPE"
fi

if ! grep -F "Node name: sensor_processor" "$METRICS_TOPIC_INFO" >/dev/null 2>&1; then
  fail "metrics topic info does not show sensor_processor as publisher"
fi

timeout --signal=INT 8s ros2 topic echo --once "$METRICS_TOPIC" "$METRICS_TYPE" | tee "$METRICS_ECHO"
if [[ "${PIPESTATUS[0]}" -ne 0 ]]; then
  fail "ros2 topic echo did not receive one PipelineMetrics message"
fi

for required_field in \
  "received_count:" \
  "expected_count:" \
  "dropped_count:" \
  "out_of_order_count:" \
  "receive_rate_hz:" \
  "expected_rate_hz:" \
  "average_latency_ms:" \
  "p95_latency_ms:" \
  "p99_latency_ms:" \
  "drop_rate:"; do
  if ! grep -F "$required_field" "$METRICS_ECHO" >/dev/null 2>&1; then
    fail "echoed PipelineMetrics is missing $required_field"
  fi
done

if ! grep -F "event=startup" "$PROCESSOR_LAUNCH_LOG" >/dev/null 2>&1; then
  fail "processor launch log is missing structured startup event"
fi

if ! grep -F "event=first_receive" "$PROCESSOR_LAUNCH_LOG" >/dev/null 2>&1; then
  fail "processor launch log is missing structured first_receive event"
fi

if ! grep -F "event=first_metrics_publish" "$PROCESSOR_LAUNCH_LOG" >/dev/null 2>&1; then
  fail "processor launch log is missing structured first_metrics_publish event"
fi

measure_sensor_hz_with_best_effort "$SENSOR_TOPIC" "$SENSOR_TOPIC_HZ" 10.0
if [[ "$?" -ne 0 ]]; then
  fail "best-effort sensor topic hz probe did not report an average rate"
fi

SENSOR_LAST_RATE="$(awk '/average rate:/ {rate=$3} END {print rate}' "$SENSOR_TOPIC_HZ")"
if [[ -z "$SENSOR_LAST_RATE" ]]; then
  fail "sensor topic hz probe did not report an average rate"
fi

awk -v rate="$SENSOR_LAST_RATE" 'BEGIN { exit !(rate >= 90.0 && rate <= 110.0) }'
if [[ "$?" -ne 0 ]]; then
  fail "sensor topic hz outside 90-110Hz: $SENSOR_LAST_RATE"
fi

measure_metrics_hz_with_reliable "$METRICS_TOPIC" "$METRICS_TOPIC_HZ" 6.0
if [[ "$?" -ne 0 ]]; then
  fail "reliable metrics topic hz probe did not report an average rate"
fi

METRICS_LAST_RATE="$(awk '/average rate:/ {rate=$3} END {print rate}' "$METRICS_TOPIC_HZ")"
if [[ -z "$METRICS_LAST_RATE" ]]; then
  fail "metrics topic hz probe did not report an average rate"
fi

awk -v rate="$METRICS_LAST_RATE" 'BEGIN { exit !(rate >= 0.5 && rate <= 2.0) }'
if [[ "$?" -ne 0 ]]; then
  fail "metrics topic hz outside 0.5-2.0Hz: $METRICS_LAST_RATE"
fi

mkdir -p "$BAG_PARENT"
timeout --signal=INT 8s ros2 bag record "$SENSOR_TOPIC" "$METRICS_TOPIC" -o "$BAG_DIR" > "$BAG_RECORD_LOG" 2>&1

ros2 bag info "$BAG_DIR" | tee "$BAG_INFO"
if [[ "${PIPESTATUS[0]}" -ne 0 ]]; then
  fail "ros2 bag info failed"
fi

if ! grep -F "Topic: $SENSOR_TOPIC" "$BAG_INFO" >/dev/null 2>&1; then
  fail "bag info does not include $SENSOR_TOPIC"
fi

if ! grep -F "Topic: $METRICS_TOPIC" "$BAG_INFO" >/dev/null 2>&1; then
  fail "bag info does not include $METRICS_TOPIC"
fi

BAG_MESSAGES="$(awk '/^Messages:/ {print $2}' "$BAG_INFO")"
if [[ -z "$BAG_MESSAGES" ]] || [[ "$BAG_MESSAGES" -le 0 ]]; then
  fail "bag contains no messages"
fi

cleanup_launches
collect_git_status
write_report
