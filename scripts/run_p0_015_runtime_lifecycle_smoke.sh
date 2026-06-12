#!/usr/bin/env bash
set -uo pipefail

# Verifies project-local P0 runtime start/stop lifecycle.
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
RUNTIME_DIR="$REPO_ROOT/runtime"
ARTIFACT_DIR="$RUNTIME_DIR/artifacts/preflight"
RESULT_DIR="$RUNTIME_DIR/results"
LOG_DIR="$RUNTIME_DIR/logs/runtime"
RUN_DIR="$RUNTIME_DIR/run/p0_runtime"

BUILD_LOG="$ARTIFACT_DIR/p0_015_colcon_build.txt"
TEST_LOG="$ARTIFACT_DIR/p0_015_colcon_test.txt"
TEST_RESULT_LOG="$ARTIFACT_DIR/p0_015_colcon_test_result.txt"
NODE_LIST="$RESULT_DIR/p0_015_node_list.txt"
TOPIC_LIST="$RESULT_DIR/p0_015_topic_list_typed.txt"
HEALTH_ECHO="$RESULT_DIR/p0_015_health_echo_once.txt"
START_OUTPUT="$RESULT_DIR/p0_015_start_output.txt"
STOP_OUTPUT="$RESULT_DIR/p0_015_stop_output.txt"
PID_CHECK="$RESULT_DIR/p0_015_pid_check.txt"
GIT_STATUS="$RESULT_DIR/p0_015_git_status.txt"
REPORT="$RESULT_DIR/p0_015_smoke_report.txt"

COLCON_STATUS="not_run"
COLCON_TEST_STATUS="not_run"
START_STATUS="not_run"
STOP_STATUS="not_run"
VERDICT="PASS"
BLOCKER="-"

mkdir -p "$ARTIFACT_DIR" "$RESULT_DIR" "$LOG_DIR" "$RUN_DIR"

print_head() {
  local file="$1"
  if [[ -f "$file" ]]; then
    sed -n '1,18p' "$file"
  else
    echo "(missing $file)"
  fi
}

print_tail() {
  local file="$1"
  if [[ -f "$file" ]]; then
    tail -n 18 "$file"
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

write_report() {
  {
    echo "P0-015_RESULT"
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
    echo "Runtime Lifecycle"
    echo "start exit status: $START_STATUS"
    echo "stop exit status: $STOP_STATUS"
    echo "run dir: $RUN_DIR"
    echo "log dir: $LOG_DIR"
    echo "manifest path: $RUN_DIR/manifest.tsv"
    echo "status file:"
    print_head "$RUN_DIR/status.txt"
    echo "start output tail:"
    print_tail "$START_OUTPUT"
    echo "stop output tail:"
    print_tail "$STOP_OUTPUT"
    echo
    echo "Runtime Evidence"
    echo "node list:"
    print_head "$NODE_LIST"
    echo "topic list:"
    print_head "$TOPIC_LIST"
    echo "health echo once:"
    print_head "$HEALTH_ECHO"
    echo "pid check:"
    print_head "$PID_CHECK"
    echo
    echo "Git / Runtime Hygiene"
    echo "git status:"
    print_head "$GIT_STATUS"
    echo "runtime artifact paths:"
    echo "$BUILD_LOG"
    echo "$TEST_LOG"
    echo "$TEST_RESULT_LOG"
    echo "$START_OUTPUT"
    echo "$STOP_OUTPUT"
    echo "$NODE_LIST"
    echo "$TOPIC_LIST"
    echo "$HEALTH_ECHO"
    echo "$PID_CHECK"
    echo "$LOG_DIR"
    echo "$RUN_DIR"
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
  bash "$SCRIPT_DIR/stop_runtime.sh" > "$STOP_OUTPUT" 2>&1 || true
  collect_git_status
  write_report
  exit 1
}

check_manifest_pids_stopped() {
  local archive
  local label
  local pid
  local log_file
  local command
  local failed=0

  : > "$PID_CHECK"
  archive="$(awk -F= '$1 == "manifest_archive" { print $2 }' "$RUN_DIR/status.txt" 2>/dev/null || true)"
  if [[ -z "$archive" || ! -f "$archive" ]]; then
    echo "missing manifest archive" | tee -a "$PID_CHECK"
    return 1
  fi

  while IFS=$'\t' read -r label pid log_file command; do
    [[ "$label" == "label" || -z "$label" ]] && continue
    if kill -0 "$pid" 2>/dev/null; then
      echo "alive: label=$label pid=$pid log=$log_file" | tee -a "$PID_CHECK"
      failed=1
    else
      echo "stopped: label=$label pid=$pid log=$log_file" | tee -a "$PID_CHECK"
    fi
  done < "$archive"

  return "$failed"
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
  > "$TEST_RESULT_LOG" 2>&1 || true
if [[ "$COLCON_TEST_STATUS" -ne 0 ]]; then
  fail "colcon test failed"
fi

source_setup_with_nounset_disabled install/setup.bash "ros2_ws install setup"

bash "$SCRIPT_DIR/stop_runtime.sh" > "$STOP_OUTPUT" 2>&1 || true

cd "$REPO_ROOT" || fail "repo root missing"
bash "$SCRIPT_DIR/start_runtime.sh" > "$START_OUTPUT" 2>&1
START_STATUS="$?"
if [[ "$START_STATUS" -ne 0 ]]; then
  fail "start_runtime.sh failed"
fi

source_setup_with_nounset_disabled "$REPO_ROOT/ros2_ws/install/setup.bash" "ros2_ws install setup"

ros2 node list | sort | tee "$NODE_LIST"
if [[ "${PIPESTATUS[0]}" -ne 0 ]]; then
  fail "ros2 node list failed"
fi

for node in /fake_sensor_adapter /sensor_processor /system_metrics_node /health_monitor; do
  if ! grep -Fx "$node" "$NODE_LIST" >/dev/null 2>&1; then
    fail "node list missing $node"
  fi
done

ros2 topic list -t | tee "$TOPIC_LIST"
if [[ "${PIPESTATUS[0]}" -ne 0 ]]; then
  fail "ros2 topic list failed"
fi

for topic in \
  "/edge/sensors/fake_primary [edge_reliability_msgs/msg/SensorSample]" \
  "/edge/metrics/pipeline [edge_reliability_msgs/msg/PipelineMetrics]" \
  "/edge/metrics/system [edge_reliability_msgs/msg/SystemMetrics]" \
  "/edge/health/state [edge_reliability_msgs/msg/HealthState]"; do
  if ! grep -F "$topic" "$TOPIC_LIST" >/dev/null 2>&1; then
    fail "topic list missing $topic"
  fi
done

timeout --signal=INT 10s ros2 topic echo --once /edge/health/state edge_reliability_msgs/msg/HealthState | tee "$HEALTH_ECHO"
if [[ "${PIPESTATUS[0]}" -ne 0 ]]; then
  fail "health state echo failed"
fi

bash "$SCRIPT_DIR/stop_runtime.sh" > "$STOP_OUTPUT" 2>&1
STOP_STATUS="$?"
if [[ "$STOP_STATUS" -ne 0 ]]; then
  fail "stop_runtime.sh failed"
fi

if ! check_manifest_pids_stopped; then
  fail "project-started processes still alive after stop"
fi

collect_git_status
write_report
