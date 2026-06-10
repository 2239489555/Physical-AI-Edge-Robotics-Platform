#!/usr/bin/env bash
set -uo pipefail

# Writes evidence under runtime/results, runtime/logs, and runtime/bags/p0-006.
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
RUNTIME_DIR="$REPO_ROOT/runtime"
ARTIFACT_DIR="$RUNTIME_DIR/artifacts/preflight"
LOG_DIR="$RUNTIME_DIR/logs"
RESULT_DIR="$RUNTIME_DIR/results"
BAG_PARENT="$RUNTIME_DIR/bags/p0-006"
BAG_DIR="$BAG_PARENT/fake_sensor_smoke_$(date -u +%Y%m%dT%H%M%SZ)"

TOPIC="/edge/sensors/fake_primary"
TYPE="edge_reliability_msgs/msg/SensorSample"

BUILD_LOG="$ARTIFACT_DIR/p0_006_colcon_build.txt"
LAUNCH_LOG="$LOG_DIR/p0_006_fake_sensor_launch.txt"
BAG_RECORD_LOG="$LOG_DIR/p0_006_bag_record.txt"
LAUNCH_PROCESS="$RESULT_DIR/p0_006_launch_process.txt"
TOPIC_LIST="$RESULT_DIR/p0_006_topic_list_typed.txt"
TOPIC_INFO="$RESULT_DIR/p0_006_topic_info_verbose.txt"
TOPIC_ECHO="$RESULT_DIR/p0_006_topic_echo_once.txt"
TOPIC_HZ="$RESULT_DIR/p0_006_topic_hz.txt"
BAG_INFO="$RESULT_DIR/p0_006_bag_info.txt"
GIT_STATUS="$RESULT_DIR/p0_006_git_status.txt"
REPORT="$RESULT_DIR/p0_006_smoke_report.txt"

COLCON_STATUS="not_run"
LAUNCH_PID=""
LAUNCH_PID_REPORTED=""
VERDICT="PASS"
BLOCKER="-"
LAST_RATE=""
BAG_MESSAGES=""

mkdir -p "$ARTIFACT_DIR" "$LOG_DIR" "$RESULT_DIR" "$BAG_PARENT"

trap cleanup_launch EXIT

cleanup_launch() {
  if [[ -n "${LAUNCH_PID:-}" ]] && kill -0 "$LAUNCH_PID" 2>/dev/null; then
    kill -INT "$LAUNCH_PID" 2>/dev/null || true
    wait "$LAUNCH_PID" 2>/dev/null || true
  fi
  LAUNCH_PID=""
}

print_head() {
  local file="$1"
  if [[ -f "$file" ]]; then
    sed -n '1,12p' "$file"
  else
    echo "(missing $file)"
  fi
}

print_tail() {
  local file="$1"
  if [[ -f "$file" ]]; then
    tail -n 12 "$file"
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

write_report() {
  mkdir -p "$RESULT_DIR"
  {
    echo "P0-006_RESULT"
    echo
    echo "Build"
    echo "colcon exit status: $COLCON_STATUS"
    echo "build summary:"
    print_summary_lines "$BUILD_LOG"
    echo "build tail:"
    print_tail "$BUILD_LOG"
    echo
    echo "Launch"
    echo "launch pid: ${LAUNCH_PID_REPORTED:-stopped}"
    echo "launch process:"
    print_head "$LAUNCH_PROCESS"
    echo "launch log head:"
    print_head "$LAUNCH_LOG"
    echo "launch log tail:"
    print_tail "$LAUNCH_LOG"
    echo
    echo "Topic Evidence"
    echo "typed topic list:"
    print_head "$TOPIC_LIST"
    echo "topic info:"
    print_head "$TOPIC_INFO"
    echo "topic echo once:"
    print_head "$TOPIC_ECHO"
    echo "topic hz:"
    print_tail "$TOPIC_HZ"
    echo "last average rate: ${LAST_RATE:-unknown}"
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
    echo "$LAUNCH_LOG"
    echo "$LAUNCH_PROCESS"
    echo "$TOPIC_LIST"
    echo "$TOPIC_INFO"
    echo "$TOPIC_ECHO"
    echo "$TOPIC_HZ"
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
  cleanup_launch
  collect_git_status
  write_report
  exit 1
}

if [[ -f "$SCRIPT_DIR/setup_runtime_dirs.sh" ]]; then
  bash "$SCRIPT_DIR/setup_runtime_dirs.sh" || fail "setup_runtime_dirs.sh failed"
fi

if [[ ! -f /opt/ros/humble/setup.bash ]]; then
  fail "/opt/ros/humble/setup.bash not found"
fi

# shellcheck source=/dev/null
source /opt/ros/humble/setup.bash || fail "failed to source ROS 2 Humble setup"

cd "$REPO_ROOT/ros2_ws" || fail "ros2_ws directory missing"

colcon build --packages-select edge_reliability_msgs edge_reliability_fake_sensor --symlink-install \
  2>&1 | tee "$BUILD_LOG"
COLCON_STATUS="$?"
if [[ "$COLCON_STATUS" -ne 0 ]]; then
  fail "colcon build failed"
fi

# shellcheck source=/dev/null
source install/setup.bash || fail "failed to source ros2_ws install setup"

ros2 daemon stop >/dev/null 2>&1 || true
ros2 daemon start >/dev/null 2>&1 || true
sleep 2

ros2 launch edge_reliability_fake_sensor fake_sensor.launch.py > "$LAUNCH_LOG" 2>&1 &
LAUNCH_PID="$!"
LAUNCH_PID_REPORTED="$LAUNCH_PID"
sleep 4

if ! kill -0 "$LAUNCH_PID" 2>/dev/null; then
  ps -p "$LAUNCH_PID" -o pid,cmd > "$LAUNCH_PROCESS" 2>&1 || true
  fail "fake sensor launch exited early"
fi

ps -p "$LAUNCH_PID" -o pid,cmd | tee "$LAUNCH_PROCESS"

ros2 topic list -t | tee "$TOPIC_LIST"
if [[ "$?" -ne 0 ]]; then
  fail "ros2 topic list failed"
fi

ros2 topic info "$TOPIC" -v | tee "$TOPIC_INFO"
if [[ "$?" -ne 0 ]]; then
  fail "ros2 topic info failed"
fi

if ! grep -F "Type: $TYPE" "$TOPIC_INFO" >/dev/null 2>&1; then
  fail "topic info does not report type $TYPE"
fi

if ! grep -F "Node name: fake_sensor_adapter" "$TOPIC_INFO" >/dev/null 2>&1; then
  fail "topic info does not show fake_sensor_adapter as publisher"
fi

timeout --signal=INT 8s ros2 topic echo --once "$TOPIC" "$TYPE" --qos-reliability best_effort | tee "$TOPIC_ECHO"
if [[ "$?" -ne 0 ]]; then
  fail "ros2 topic echo did not receive one SensorSample"
fi

if ! grep -F "header:" "$TOPIC_ECHO" >/dev/null 2>&1; then
  fail "echoed SensorSample is missing header"
fi

if ! grep -F "sequence_id:" "$TOPIC_ECHO" >/dev/null 2>&1; then
  fail "echoed SensorSample is missing sequence_id"
fi

if ! grep -F "sensor_id: fake_primary" "$TOPIC_ECHO" >/dev/null 2>&1; then
  fail "echoed SensorSample does not use sensor_id fake_primary"
fi

if ! grep -F "value:" "$TOPIC_ECHO" >/dev/null 2>&1; then
  fail "echoed SensorSample is missing value"
fi

if ! grep -F "status:" "$TOPIC_ECHO" >/dev/null 2>&1; then
  fail "echoed SensorSample is missing status"
fi

if ! grep -F "status_detail: ok" "$TOPIC_ECHO" >/dev/null 2>&1; then
  fail "echoed SensorSample does not report status_detail ok"
fi

if ! grep -F "event=startup" "$LAUNCH_LOG" >/dev/null 2>&1; then
  fail "launch log is missing structured startup event"
fi

if ! grep -F "event=first_publish" "$LAUNCH_LOG" >/dev/null 2>&1; then
  fail "launch log is missing structured first_publish event"
fi

timeout --signal=INT 12s ros2 topic hz "$TOPIC" --qos-reliability best_effort | tee "$TOPIC_HZ"
LAST_RATE="$(awk '/average rate:/ {rate=$3} END {print rate}' "$TOPIC_HZ")"
if [[ -z "$LAST_RATE" ]]; then
  fail "ros2 topic hz did not report an average rate"
fi

awk -v rate="$LAST_RATE" 'BEGIN { exit !(rate >= 90.0 && rate <= 110.0) }'
if [[ "$?" -ne 0 ]]; then
  fail "topic hz outside 90-110Hz: $LAST_RATE"
fi

mkdir -p "$BAG_PARENT"
timeout --signal=INT 8s ros2 bag record "$TOPIC" -o "$BAG_DIR" > "$BAG_RECORD_LOG" 2>&1

ros2 bag info "$BAG_DIR" | tee "$BAG_INFO"
if [[ "$?" -ne 0 ]]; then
  fail "ros2 bag info failed"
fi

if ! grep -F "Topic: $TOPIC" "$BAG_INFO" >/dev/null 2>&1; then
  fail "bag info does not include $TOPIC"
fi

BAG_MESSAGES="$(awk '/^Messages:/ {print $2}' "$BAG_INFO")"
if [[ -z "$BAG_MESSAGES" ]] || [[ "$BAG_MESSAGES" -le 0 ]]; then
  fail "bag contains no messages"
fi

cleanup_launch
collect_git_status
write_report
