#!/usr/bin/env bash
set -uo pipefail

# Runs P0-013 QoS experiments for 100Hz and 200Hz.
# Runtime outputs stay under runtime/results/qos, runtime/logs/qos, and runtime/tmp/p0-013.
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
RUNTIME_DIR="$REPO_ROOT/runtime"
ARTIFACT_DIR="$RUNTIME_DIR/artifacts/preflight"
RESULT_DIR="$RUNTIME_DIR/results"
QOS_RESULT_DIR="$RESULT_DIR/qos"
LOG_DIR="$RUNTIME_DIR/logs"
QOS_LOG_DIR="$LOG_DIR/qos"
TMP_DIR="$RUNTIME_DIR/tmp/p0-013"
CONFIG_DIR="$TMP_DIR/configs"

SENSOR_TOPIC="/edge/sensors/fake_primary"
METRICS_TOPIC="/edge/metrics/pipeline"
SYSTEM_TOPIC="/edge/metrics/system"
SENSOR_TYPE="edge_reliability_msgs/msg/SensorSample"
METRICS_TYPE="edge_reliability_msgs/msg/PipelineMetrics"
SYSTEM_TYPE="edge_reliability_msgs/msg/SystemMetrics"
SYSTEM_SAMPLE_FILE="$REPO_ROOT/ros2_ws/src/edge_reliability_system/testdata/tegrastats_samples.txt"

BUILD_LOG="$ARTIFACT_DIR/p0_013_colcon_build.txt"
TEST_LOG="$ARTIFACT_DIR/p0_013_colcon_test.txt"
TEST_RESULT_LOG="$ARTIFACT_DIR/p0_013_colcon_test_result.txt"
GIT_STATUS="$RESULT_DIR/p0_013_git_status.txt"
REPORT="$RESULT_DIR/p0_013_smoke_report.txt"
CSV_PATH="$QOS_RESULT_DIR/p0_013_qos_results.csv"
MARKDOWN_REPORT="$QOS_RESULT_DIR/p0_013_qos_report.md"

COLCON_STATUS="not_run"
COLCON_TEST_STATUS="not_run"
VERDICT="PASS"
BLOCKER="-"
ACTIVE_FAKE_PID=""
ACTIVE_PROCESSOR_PID=""
ACTIVE_SYSTEM_PID=""
SCENARIO_COUNT=0

WARMUP_SECONDS=6
CAPTURE_SECONDS=7
CLEANUP_INT_WAIT_SECONDS=8
CLEANUP_TERM_WAIT_SECONDS=5

mkdir -p "$ARTIFACT_DIR" "$RESULT_DIR" "$QOS_RESULT_DIR" "$LOG_DIR" "$QOS_LOG_DIR" "$CONFIG_DIR"

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

  stop_background_process "${ACTIVE_PROCESSOR_PID:-}" "processor launch"
  ACTIVE_PROCESSOR_PID=""

  stop_background_process "${ACTIVE_FAKE_PID:-}" "fake sensor launch"
  ACTIVE_FAKE_PID=""
}

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

summary_value() {
  local key="$1"
  local file="$2"
  awk -F': ' -v key="$key" '$1 == key { value = $2 } END { print value }' "$file"
}

write_fake_config() {
  local path="$1"
  local hz="$2"
  local reliability="$3"
  local depth="$4"

  cat > "$path" <<EOF
fake_sensor_adapter:
  ros__parameters:
    topic: /edge/sensors/fake_primary
    sensor_id: fake_primary
    frame_id: fake_sensor_frame
    publish_hz: $hz
    status_mode: "ok"
    fault_mode: "off"
    drop_enabled: false
    drop_probability: 0.0
    drop_seed: 1
    qos_depth: $depth
    qos_reliability: $reliability
EOF
}

write_processor_config() {
  local path="$1"
  local hz="$2"
  local reliability="$3"
  local depth="$4"

  cat > "$path" <<EOF
sensor_processor:
  ros__parameters:
    sensor_topic: /edge/sensors/fake_primary
    metrics_topic: /edge/metrics/pipeline
    metrics_frame_id: pipeline_metrics_frame
    expected_hz: $hz
    metrics_publish_hz: 1.0
    latency_warn_ms: 20.0
    latency_unhealthy_ms: 50.0
    sensor_qos_depth: $depth
    sensor_qos_reliability: $reliability
    metrics_qos_depth: 10
    rate_window_seconds: 5.0
    latency_window_size: 2000
    processing_delay_enabled: false
    processing_delay_ms: 0.0
EOF
}

capture_metrics_summary() {
  local output_file="$1"
  local sample_seconds="${2:-7.0}"

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
        super().__init__("p0_013_metrics_probe")
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

capture_system_metrics_summary() {
  local output_file="$1"
  local sample_seconds="${2:-4.0}"

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
        super().__init__("p0_013_system_probe")
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
print(f"last_temperature_c: {last.temperature_c:.3f}")
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

append_csv_row() {
  local scenario="$1"
  local hz="$2"
  local reliability="$3"
  local depth="$4"
  local metrics_summary="$5"
  local system_summary="$6"

  local receive_rate
  local drop_rate
  local average_latency
  local p95_latency
  local p99_latency
  local cpu_percent
  local memory_used
  local memory_total
  local temperature
  local notes

  receive_rate="$(summary_value "last_receive_rate_hz" "$metrics_summary")"
  drop_rate="$(summary_value "last_drop_rate" "$metrics_summary")"
  average_latency="$(summary_value "last_average_latency_ms" "$metrics_summary")"
  p95_latency="$(summary_value "last_p95_latency_ms" "$metrics_summary")"
  p99_latency="$(summary_value "last_p99_latency_ms" "$metrics_summary")"
  cpu_percent="$(summary_value "last_cpu_percent" "$system_summary")"
  memory_used="$(summary_value "last_memory_used_mb" "$system_summary")"
  memory_total="$(summary_value "last_memory_total_mb" "$system_summary")"
  temperature="$(summary_value "last_temperature_c" "$system_summary")"
  notes="matched_${reliability}_depth_${depth}"

  printf '%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s\n' \
    "$scenario" \
    "$hz" \
    "$reliability" \
    "$reliability" \
    "$depth" \
    "$receive_rate" \
    "$drop_rate" \
    "$average_latency" \
    "$p95_latency" \
    "$p99_latency" \
    "$cpu_percent" \
    "$memory_used" \
    "$memory_total" \
    "$temperature" \
    "$notes" >> "$CSV_PATH"
}

run_qos_scenario() {
  local hz="$1"
  local reliability="$2"
  local depth="$3"
  local scenario="qos_${hz}hz_${reliability}_depth${depth}"
  local fake_config="$CONFIG_DIR/${scenario}_fake_sensor.yaml"
  local processor_config="$CONFIG_DIR/${scenario}_processor.yaml"
  local metrics_summary="$QOS_RESULT_DIR/${scenario}_metrics_summary.txt"
  local system_summary="$QOS_RESULT_DIR/${scenario}_system_summary.txt"
  local sensor_topic_info="$QOS_RESULT_DIR/${scenario}_sensor_topic_info.txt"
  local metrics_topic_info="$QOS_RESULT_DIR/${scenario}_metrics_topic_info.txt"
  local fake_log="$QOS_LOG_DIR/${scenario}_fake_sensor_launch.txt"
  local processor_log="$QOS_LOG_DIR/${scenario}_processor_launch.txt"
  local system_log="$QOS_LOG_DIR/${scenario}_system_metrics_launch.txt"
  local fake_process="$QOS_RESULT_DIR/${scenario}_fake_launch_process.txt"
  local processor_process="$QOS_RESULT_DIR/${scenario}_processor_launch_process.txt"
  local system_process="$QOS_RESULT_DIR/${scenario}_system_launch_process.txt"
  local raw_log="$QOS_LOG_DIR/${scenario}_tegrastats_raw.log"

  write_fake_config "$fake_config" "$hz" "$reliability" "$depth"
  write_processor_config "$processor_config" "$hz" "$reliability" "$depth"
  : > "$raw_log"

  ACTIVE_FAKE_PID="$(launch_and_check "$scenario fake sensor launch" "$fake_log" "$fake_process" \
    ros2 launch edge_reliability_fake_sensor fake_sensor.launch.py "config_file:=$fake_config")"
  ACTIVE_PROCESSOR_PID="$(launch_and_check "$scenario processor launch" "$processor_log" "$processor_process" \
    ros2 launch edge_reliability_processor processor.launch.py "config_file:=$processor_config")"
  ACTIVE_SYSTEM_PID="$(launch_and_check "$scenario system metrics launch" "$system_log" "$system_process" \
    ros2 launch edge_reliability_system system_metrics.launch.py \
      "sample_file:=$SYSTEM_SAMPLE_FILE" "raw_log_path:=$raw_log" "disk_path:=$REPO_ROOT")"

  sleep "$WARMUP_SECONDS"

  ros2 topic info "$SENSOR_TOPIC" -v | tee "$sensor_topic_info" >/dev/null
  ros2 topic info "$METRICS_TOPIC" -v | tee "$metrics_topic_info" >/dev/null

  capture_metrics_summary "$metrics_summary" "$CAPTURE_SECONDS"
  if [[ "$?" -ne 0 ]]; then
    fail "$scenario metrics capture failed"
  fi

  capture_system_metrics_summary "$system_summary" 4
  if [[ "$?" -ne 0 ]]; then
    fail "$scenario system metrics capture failed"
  fi

  if ! grep -F "event=startup" "$fake_log" >/dev/null 2>&1; then
    fail "$scenario fake sensor startup log missing"
  fi
  if ! grep -F "qos_reliability=$reliability" "$fake_log" >/dev/null 2>&1; then
    fail "$scenario fake sensor QoS log missing $reliability"
  fi
  if ! grep -F "event=startup" "$processor_log" >/dev/null 2>&1; then
    fail "$scenario processor startup log missing"
  fi
  if ! grep -F "sensor_qos_reliability=$reliability" "$processor_log" >/dev/null 2>&1; then
    fail "$scenario processor QoS log missing $reliability"
  fi

  append_csv_row "$scenario" "$hz" "$reliability" "$depth" "$metrics_summary" "$system_summary"
  SCENARIO_COUNT=$((SCENARIO_COUNT + 1))

  cleanup_launches
  sleep 2
}

write_markdown_report() {
  {
    echo "# P0-013 QoS Experiment Report"
    echo
    echo "CSV: \`$CSV_PATH\`"
    echo
    echo "## Scenario Matrix"
    echo
    echo "| Scenario | Frequency Hz | Reliability | KeepLast Depth | Receive Rate Hz | Drop Rate | Avg Latency Ms | P95 Latency Ms | P99 Latency Ms | CPU % | RAM Used MiB | RAM Total MiB | Temperature C | Notes |"
    echo "| --- | ---: | --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: | --- |"
    awk -F, 'NR > 1 {
      printf "| %s | %s | %s/%s | %s | %s | %s | %s | %s | %s | %s | %s | %s | %s | %s |\n",
        $1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, $12, $13, $14, $15
    }' "$CSV_PATH"
    echo
    echo "## Observed Tradeoffs"
    echo
    echo "- 100Hz and 200Hz scenarios are recorded separately so receive-rate headroom can be compared against the target frequency."
    echo "- BestEffort favors freshness and is the default for high-rate sensor streams; Reliable asks DDS to preserve delivery when publisher and subscriber policies match."
    echo "- KeepLast depth is recorded because larger queues can absorb bursts but may increase latency if a subscriber falls behind."
    echo "- CPU, RAM, and temperature columns are captured from the system metrics topic when available so communication metrics can be read alongside Jetson state."
    echo
    echo "## Notes"
    echo
    echo "P0-013 intentionally limits the matrix to 100Hz and 200Hz. 500Hz and 1000Hz pressure runs remain P0-014."
  } > "$MARKDOWN_REPORT"
}

write_report() {
  mkdir -p "$RESULT_DIR"
  {
    echo "P0-013_RESULT"
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
    echo "Experiment Matrix"
    echo "scenario count: $SCENARIO_COUNT"
    echo "frequencies: 100,200"
    echo "reliability profiles: best_effort,reliable"
    echo "keep_last depths: 10,50"
    echo "sensor topic: $SENSOR_TOPIC"
    echo "sensor type: $SENSOR_TYPE"
    echo "metrics topic: $METRICS_TOPIC"
    echo "metrics type: $METRICS_TYPE"
    echo "system topic: $SYSTEM_TOPIC"
    echo "system type: $SYSTEM_TYPE"
    echo
    echo "CSV Results"
    echo "csv path: $CSV_PATH"
    echo "csv header:"
    sed -n '1p' "$CSV_PATH"
    echo "csv preview:"
    sed -n '1,10p' "$CSV_PATH"
    echo
    echo "Markdown Report"
    echo "markdown report path: $MARKDOWN_REPORT"
    echo "markdown report head:"
    print_head "$MARKDOWN_REPORT"
    echo
    echo "Git / Runtime Hygiene"
    echo "git status:"
    print_head "$GIT_STATUS"
    echo "runtime artifact paths:"
    echo "$BUILD_LOG"
    echo "$TEST_LOG"
    echo "$TEST_RESULT_LOG"
    echo "$CSV_PATH"
    echo "$MARKDOWN_REPORT"
    echo "$QOS_RESULT_DIR"
    echo "$QOS_LOG_DIR"
    echo "$CONFIG_DIR"
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
  if [[ -f "$CSV_PATH" ]]; then
    write_markdown_report || true
  fi
  write_report
  exit 1
}

if [[ -f "$SCRIPT_DIR/setup_runtime_dirs.sh" ]]; then
  bash "$SCRIPT_DIR/setup_runtime_dirs.sh" || fail "setup_runtime_dirs.sh failed"
fi

source_setup_with_nounset_disabled /opt/ros/humble/setup.bash "ROS 2 Humble setup"

cd "$REPO_ROOT/ros2_ws" || fail "ros2_ws directory missing"

colcon build --packages-select edge_reliability_msgs edge_reliability_fake_sensor edge_reliability_processor edge_reliability_system --symlink-install \
  2>&1 | tee "$BUILD_LOG"
COLCON_STATUS="${PIPESTATUS[0]}"
if [[ "$COLCON_STATUS" -ne 0 ]]; then
  fail "colcon build failed"
fi

if grep -F "package had stderr output" "$BUILD_LOG" >/dev/null 2>&1; then
  fail "colcon build reported package stderr output"
fi

colcon test --packages-select edge_reliability_processor edge_reliability_system \
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

printf 'scenario_name,frequency_hz,sensor_qos_reliability,processor_qos_reliability,qos_depth,receive_rate_hz,drop_rate,average_latency_ms,p95_latency_ms,p99_latency_ms,cpu_percent,memory_used_mb,memory_total_mb,temperature_c,notes\n' > "$CSV_PATH"

for hz in 100 200; do
  for reliability in best_effort reliable; do
    for depth in 10 50; do
      run_qos_scenario "$hz" "$reliability" "$depth"
    done
  done
done

if [[ "$SCENARIO_COUNT" -ne 8 ]]; then
  fail "expected 8 QoS scenarios, got $SCENARIO_COUNT"
fi

CSV_ROWS="$(($(wc -l < "$CSV_PATH") - 1))"
if [[ "$CSV_ROWS" -ne 8 ]]; then
  fail "expected 8 CSV data rows, got $CSV_ROWS"
fi

for required in "100,best_effort" "100,reliable" "200,best_effort" "200,reliable"; do
  IFS=, read -r required_hz required_reliability <<< "$required"
  if ! awk -F, -v hz="$required_hz" -v reliability="$required_reliability" \
    'NR > 1 && $2 == hz && $3 == reliability { found = 1 } END { exit !found }' "$CSV_PATH"; then
    fail "missing CSV scenario for ${required_hz}Hz ${required_reliability}"
  fi
done

write_markdown_report
collect_git_status
write_report
