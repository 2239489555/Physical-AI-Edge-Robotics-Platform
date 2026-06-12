#!/usr/bin/env bash
set -uo pipefail

# Runs P0-014 pressure experiments for 500Hz and 1000Hz.
# Runtime outputs stay under runtime/results/qos, runtime/logs/qos, runtime/bags/qos,
# and runtime/tmp/p0-014.
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
RUNTIME_DIR="$REPO_ROOT/runtime"
ARTIFACT_DIR="$RUNTIME_DIR/artifacts/preflight"
RESULT_DIR="$RUNTIME_DIR/results"
QOS_RESULT_DIR="$RESULT_DIR/qos"
LOG_DIR="$RUNTIME_DIR/logs"
QOS_LOG_DIR="$LOG_DIR/qos"
QOS_BAG_DIR="$RUNTIME_DIR/bags/qos"
TMP_DIR="$RUNTIME_DIR/tmp/p0-014"
CONFIG_DIR="$TMP_DIR/configs"

SENSOR_TOPIC="/edge/sensors/fake_primary"
METRICS_TOPIC="/edge/metrics/pipeline"
SYSTEM_TOPIC="/edge/metrics/system"
SENSOR_TYPE="edge_reliability_msgs/msg/SensorSample"
METRICS_TYPE="edge_reliability_msgs/msg/PipelineMetrics"
SYSTEM_TYPE="edge_reliability_msgs/msg/SystemMetrics"
SYSTEM_SAMPLE_FILE="$REPO_ROOT/ros2_ws/src/edge_reliability_system/testdata/tegrastats_samples.txt"

BUILD_LOG="$ARTIFACT_DIR/p0_014_colcon_build.txt"
TEST_LOG="$ARTIFACT_DIR/p0_014_colcon_test.txt"
TEST_RESULT_LOG="$ARTIFACT_DIR/p0_014_colcon_test_result.txt"
GIT_STATUS="$RESULT_DIR/p0_014_git_status.txt"
REPORT="$RESULT_DIR/p0_014_smoke_report.txt"
CSV_PATH="$QOS_RESULT_DIR/p0_014_pressure_results.csv"
MARKDOWN_REPORT="$QOS_RESULT_DIR/p0_014_pressure_report.md"

COLCON_STATUS="not_run"
COLCON_TEST_STATUS="not_run"
VERDICT="PASS"
BLOCKER="-"
ACTIVE_FAKE_PID=""
ACTIVE_PROCESSOR_PID=""
ACTIVE_SYSTEM_PID=""
SCENARIO_COUNT=0
PRESSURE_SCENARIO_COUNT=0
MISMATCH_SCENARIO_COUNT=0
CURRENT_SCENARIO="-"
CURRENT_TOPIC_LIST=""
CURRENT_FAKE_LOG=""
CURRENT_PROCESSOR_LOG=""
CURRENT_SYSTEM_LOG=""

WARMUP_SECONDS=6
CAPTURE_SECONDS=7
TOPIC_WAIT_SECONDS=25
CLEANUP_INT_WAIT_SECONDS=8
CLEANUP_TERM_WAIT_SECONDS=5

mkdir -p "$ARTIFACT_DIR" "$RESULT_DIR" "$QOS_RESULT_DIR" "$LOG_DIR" "$QOS_LOG_DIR" "$QOS_BAG_DIR" "$CONFIG_DIR"

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

as_yaml_double() {
  local value="$1"

  if [[ "$value" == *.* ]]; then
    printf '%s\n' "$value"
  else
    printf '%s.0\n' "$value"
  fi
}

write_fake_config() {
  local path="$1"
  local hz="$2"
  local reliability="$3"
  local depth="$4"
  local hz_double

  hz_double="$(as_yaml_double "$hz")"

  cat > "$path" <<EOF
fake_sensor_adapter:
  ros__parameters:
    topic: /edge/sensors/fake_primary
    sensor_id: fake_primary
    frame_id: fake_sensor_frame
    publish_hz: $hz_double
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
  local hz_double

  hz_double="$(as_yaml_double "$hz")"

  cat > "$path" <<EOF
sensor_processor:
  ros__parameters:
    sensor_topic: /edge/sensors/fake_primary
    metrics_topic: /edge/metrics/pipeline
    metrics_frame_id: pipeline_metrics_frame
    expected_hz: $hz_double
    metrics_publish_hz: 1.0
    latency_warn_ms: 20.0
    latency_unhealthy_ms: 50.0
    sensor_qos_depth: $depth
    sensor_qos_reliability: $reliability
    metrics_qos_depth: 10
    rate_window_seconds: 5.0
    latency_window_size: 5000
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
        super().__init__("p0_014_metrics_probe")
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
        super().__init__("p0_014_system_probe")
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
  local result_var="$1"
  local command_label="$2"
  local log_file="$3"
  local process_file="$4"
  shift 4

  "$@" > "$log_file" 2>&1 &
  local pid="$!"
  sleep 3

  if ! kill -0 "$pid" 2>/dev/null; then
    ps -p "$pid" -o pid,cmd > "$process_file" 2>&1 || true
    fail "$command_label exited early"
  fi

  ps -p "$pid" -o pid,cmd > "$process_file"
  printf -v "$result_var" '%s' "$pid"
}

assert_process_alive() {
  local pid="$1"
  local label="$2"

  if [[ -z "$pid" ]] || ! kill -0 "$pid" 2>/dev/null; then
    fail "$CURRENT_SCENARIO $label exited before readiness"
  fi
}

wait_for_topic_type() {
  local topic="$1"
  local topic_type="$2"
  local output_file="$3"
  local timeout_seconds="${4:-25}"
  local deadline=$((SECONDS + timeout_seconds))

  while (( SECONDS < deadline )); do
    ros2 topic list -t > "$output_file" 2>&1 || true
    if grep -F "$topic [$topic_type]" "$output_file" >/dev/null 2>&1; then
      return 0
    fi

    assert_process_alive "${ACTIVE_FAKE_PID:-}" "fake sensor launch"
    if [[ -n "${ACTIVE_PROCESSOR_PID:-}" ]]; then
      assert_process_alive "$ACTIVE_PROCESSOR_PID" "processor launch"
    fi
    if [[ -n "${ACTIVE_SYSTEM_PID:-}" ]]; then
      assert_process_alive "$ACTIVE_SYSTEM_PID" "system metrics launch"
    fi

    sleep 1
  done

  ros2 topic list -t > "$output_file" 2>&1 || true
  return 1
}

pressure_note() {
  local hz="$1"
  local receive_rate="$2"
  local drop_rate="$3"
  local p99_latency="$4"
  local scenario_kind="$5"

  if [[ "$scenario_kind" == "qos_mismatch" ]]; then
    echo "expected_qos_mismatch_no_sensor_samples"
    return 0
  fi

  awk -v hz="$hz" -v rate="$receive_rate" -v drop="$drop_rate" -v p99="$p99_latency" 'BEGIN {
    note = "pressure_observation";
    if (hz > 0 && rate / hz < 0.90) {
      note = note ";rate_below_90pct_target";
    }
    if (drop > 0.0) {
      note = note ";nonzero_drop_rate";
    }
    if (p99 > 20.0) {
      note = note ";p99_latency_pressure";
    }
    print note;
  }'
}

append_csv_row() {
  local scenario="$1"
  local scenario_kind="$2"
  local hz="$3"
  local fake_reliability="$4"
  local processor_reliability="$5"
  local depth="$6"
  local metrics_summary="$7"
  local system_summary="$8"

  local metrics_messages
  local received_count
  local expected_count
  local dropped_count
  local receive_rate
  local drop_rate
  local average_latency
  local p95_latency
  local p99_latency
  local target_ratio
  local rate_gap
  local cpu_percent
  local memory_used
  local memory_total
  local temperature
  local notes

  metrics_messages="$(summary_value "metrics_messages" "$metrics_summary")"
  received_count="$(summary_value "last_received_count" "$metrics_summary")"
  expected_count="$(summary_value "last_expected_count" "$metrics_summary")"
  dropped_count="$(summary_value "last_dropped_count" "$metrics_summary")"
  receive_rate="$(summary_value "last_receive_rate_hz" "$metrics_summary")"
  drop_rate="$(summary_value "last_drop_rate" "$metrics_summary")"
  average_latency="$(summary_value "last_average_latency_ms" "$metrics_summary")"
  p95_latency="$(summary_value "last_p95_latency_ms" "$metrics_summary")"
  p99_latency="$(summary_value "last_p99_latency_ms" "$metrics_summary")"
  cpu_percent="$(summary_value "last_cpu_percent" "$system_summary")"
  memory_used="$(summary_value "last_memory_used_mb" "$system_summary")"
  memory_total="$(summary_value "last_memory_total_mb" "$system_summary")"
  temperature="$(summary_value "last_temperature_c" "$system_summary")"

  target_ratio="$(awk -v hz="$hz" -v rate="$receive_rate" 'BEGIN { if (hz <= 0) { print "0.000" } else { printf "%.3f", rate / hz } }')"
  rate_gap="$(awk -v hz="$hz" -v rate="$receive_rate" 'BEGIN { printf "%.3f", hz - rate }')"
  notes="$(pressure_note "$hz" "$receive_rate" "$drop_rate" "$p99_latency" "$scenario_kind")"

  printf '%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s\n' \
    "$scenario" \
    "$scenario_kind" \
    "$hz" \
    "$fake_reliability" \
    "$processor_reliability" \
    "$depth" \
    "$receive_rate" \
    "$target_ratio" \
    "$rate_gap" \
    "$drop_rate" \
    "$average_latency" \
    "$p95_latency" \
    "$p99_latency" \
    "$cpu_percent" \
    "$memory_used" \
    "$memory_total" \
    "$temperature" \
    "$metrics_messages" \
    "$received_count" \
    "$expected_count" \
    "$dropped_count" \
    "$notes" >> "$CSV_PATH"
}

run_pressure_scenario() {
  local hz="$1"
  local fake_reliability="$2"
  local processor_reliability="$3"
  local depth="$4"
  local scenario_kind="$5"
  local scenario="pressure_${hz}hz_pub_${fake_reliability}_sub_${processor_reliability}_depth${depth}"
  local fake_config
  local processor_config
  local metrics_summary
  local system_summary
  local sensor_topic_info
  local metrics_topic_info
  local topic_list
  local fake_log
  local processor_log
  local system_log
  local fake_process
  local processor_process
  local system_process
  local raw_log
  local received_count

  if [[ "$scenario_kind" == "qos_mismatch" ]]; then
    scenario="qos_mismatch_${hz}hz_pub_${fake_reliability}_sub_${processor_reliability}_depth${depth}"
  fi

  fake_config="$CONFIG_DIR/${scenario}_fake_sensor.yaml"
  processor_config="$CONFIG_DIR/${scenario}_processor.yaml"
  metrics_summary="$QOS_RESULT_DIR/${scenario}_metrics_summary.txt"
  system_summary="$QOS_RESULT_DIR/${scenario}_system_summary.txt"
  sensor_topic_info="$QOS_RESULT_DIR/${scenario}_sensor_topic_info.txt"
  metrics_topic_info="$QOS_RESULT_DIR/${scenario}_metrics_topic_info.txt"
  topic_list="$QOS_RESULT_DIR/${scenario}_topic_list_typed.txt"
  fake_log="$QOS_LOG_DIR/${scenario}_fake_sensor_launch.txt"
  processor_log="$QOS_LOG_DIR/${scenario}_processor_launch.txt"
  system_log="$QOS_LOG_DIR/${scenario}_system_metrics_launch.txt"
  fake_process="$QOS_RESULT_DIR/${scenario}_fake_launch_process.txt"
  processor_process="$QOS_RESULT_DIR/${scenario}_processor_launch_process.txt"
  system_process="$QOS_RESULT_DIR/${scenario}_system_launch_process.txt"
  raw_log="$QOS_LOG_DIR/${scenario}_tegrastats_raw.log"

  CURRENT_SCENARIO="$scenario"
  CURRENT_TOPIC_LIST="$topic_list"
  CURRENT_FAKE_LOG="$fake_log"
  CURRENT_PROCESSOR_LOG="$processor_log"
  CURRENT_SYSTEM_LOG="$system_log"

  write_fake_config "$fake_config" "$hz" "$fake_reliability" "$depth"
  write_processor_config "$processor_config" "$hz" "$processor_reliability" "$depth"
  : > "$raw_log"

  launch_and_check ACTIVE_FAKE_PID "$scenario fake sensor launch" "$fake_log" "$fake_process" \
    ros2 launch edge_reliability_fake_sensor fake_sensor.launch.py "config_file:=$fake_config"

  if ! wait_for_topic_type "$SENSOR_TOPIC" "$SENSOR_TYPE" "$topic_list" "$TOPIC_WAIT_SECONDS"; then
    fail "$scenario sensor topic did not become ready"
  fi

  launch_and_check ACTIVE_PROCESSOR_PID "$scenario processor launch" "$processor_log" "$processor_process" \
    ros2 launch edge_reliability_processor processor.launch.py "config_file:=$processor_config"

  if ! wait_for_topic_type "$METRICS_TOPIC" "$METRICS_TYPE" "$topic_list" "$TOPIC_WAIT_SECONDS"; then
    fail "$scenario metrics topic did not become ready"
  fi

  launch_and_check ACTIVE_SYSTEM_PID "$scenario system metrics launch" "$system_log" "$system_process" \
    ros2 launch edge_reliability_system system_metrics.launch.py \
      "sample_file:=$SYSTEM_SAMPLE_FILE" "raw_log_path:=$raw_log" "disk_path:=$REPO_ROOT"

  if ! wait_for_topic_type "$SYSTEM_TOPIC" "$SYSTEM_TYPE" "$topic_list" "$TOPIC_WAIT_SECONDS"; then
    fail "$scenario system metrics topic did not become ready"
  fi

  sleep "$WARMUP_SECONDS"

  ros2 topic info "$SENSOR_TOPIC" -v | tee "$sensor_topic_info" >/dev/null
  if [[ "${PIPESTATUS[0]}" -ne 0 ]]; then
    fail "$scenario sensor topic info failed"
  fi
  ros2 topic info "$METRICS_TOPIC" -v | tee "$metrics_topic_info" >/dev/null
  if [[ "${PIPESTATUS[0]}" -ne 0 ]]; then
    fail "$scenario metrics topic info failed"
  fi

  capture_metrics_summary "$metrics_summary" "$CAPTURE_SECONDS"
  if [[ "$?" -ne 0 ]]; then
    fail "$scenario metrics capture failed"
  fi

  capture_system_metrics_summary "$system_summary" 4
  if [[ "$?" -ne 0 ]]; then
    fail "$scenario system metrics capture failed"
  fi

  if ! grep -F "qos_reliability=$fake_reliability" "$fake_log" >/dev/null 2>&1; then
    fail "$scenario fake sensor QoS log missing $fake_reliability"
  fi
  if ! grep -F "sensor_qos_reliability=$processor_reliability" "$processor_log" >/dev/null 2>&1; then
    fail "$scenario processor QoS log missing $processor_reliability"
  fi

  received_count="$(summary_value "last_received_count" "$metrics_summary")"
  if [[ "$scenario_kind" == "qos_mismatch" && "$received_count" -ne 0 ]]; then
    fail "$scenario expected QoS mismatch but received_count=$received_count"
  fi
  if [[ "$scenario_kind" == "pressure" && "$received_count" -le 0 ]]; then
    fail "$scenario pressure run received no sensor samples"
  fi

  append_csv_row "$scenario" "$scenario_kind" "$hz" "$fake_reliability" "$processor_reliability" "$depth" \
    "$metrics_summary" "$system_summary"

  SCENARIO_COUNT=$((SCENARIO_COUNT + 1))
  if [[ "$scenario_kind" == "qos_mismatch" ]]; then
    MISMATCH_SCENARIO_COUNT=$((MISMATCH_SCENARIO_COUNT + 1))
  else
    PRESSURE_SCENARIO_COUNT=$((PRESSURE_SCENARIO_COUNT + 1))
  fi

  cleanup_launches
  sleep 2
}

write_markdown_report() {
  {
    echo "# P0-014 Pressure Experiment Report"
    echo
    echo "CSV: \`$CSV_PATH\`"
    echo
    echo "## P0 Gate Separation"
    echo
    echo "- P0-014 passes when pressure evidence and QoS mismatch evidence are generated."
    echo "- 500Hz and 1000Hz stability is not a P0 pass condition."
    echo "- Receive-rate shortfall, drops, and latency spikes are pressure observations for bottleneck analysis."
    echo
    echo "## Scenario Matrix"
    echo
    echo "| Scenario | Kind | Frequency Hz | Pub QoS | Sub QoS | KeepLast Depth | Receive Rate Hz | Target Ratio | Rate Gap Hz | Drop Rate | Avg Latency Ms | P95 Latency Ms | P99 Latency Ms | CPU % | RAM Used MiB | RAM Total MiB | Temperature C | Metrics Messages | Received Count | Expected Count | Dropped Count | Notes |"
    echo "| --- | --- | ---: | --- | --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: | --- |"
    awk -F, 'NR > 1 {
      printf "| %s | %s | %s | %s | %s | %s | %s | %s | %s | %s | %s | %s | %s | %s | %s | %s | %s | %s | %s | %s | %s | %s |\n",
        $1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, $12, $13, $14, $15, $16, $17, $18, $19, $20, $21, $22
    }' "$CSV_PATH"
    echo
    echo "## Bottleneck Reading Guide"
    echo
    echo "- Compare target ratio and rate gap first; they show whether the subscriber kept up with the requested publish rate."
    echo "- Use drop rate and dropped count to separate sequence loss from simple receive-rate shortfall."
    echo "- Use p95 and p99 latency to identify queueing pressure, especially when larger KeepLast depth trades loss for backlog."
    echo "- Read CPU, RAM, and temperature beside communication metrics; system values are context, not proof of a single bottleneck by themselves."
    echo
    echo "## QoS Mismatch"
    echo
    echo "The mismatch rows intentionally use a BestEffort publisher with a Reliable subscriber. ROS 2 reliability compatibility should prevent sensor samples from flowing, so received count must remain zero while metrics still publish."
    echo
    echo "## Artifact Hygiene"
    echo
    echo "High-rate bags are not recorded by this smoke runner to avoid large artifacts on the company Jetson. The project-local bag directory is reserved at \`$QOS_BAG_DIR\` for later manual captures if needed."
  } > "$MARKDOWN_REPORT"
}

write_report() {
  mkdir -p "$RESULT_DIR"
  {
    echo "P0-014_RESULT"
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
    echo "Pressure Matrix"
    echo "scenario count: $SCENARIO_COUNT"
    echo "pressure scenario count: $PRESSURE_SCENARIO_COUNT"
    echo "qos mismatch scenario count: $MISMATCH_SCENARIO_COUNT"
    echo "frequencies: 500,1000"
    echo "reliability profiles: best_effort,reliable"
    echo "keep_last depths: 10,50"
    echo "mismatch profile: publisher best_effort, subscriber reliable"
    echo "p0 high-frequency stability required: no"
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
    sed -n '1,12p' "$CSV_PATH"
    echo
    echo "Markdown Report"
    echo "markdown report path: $MARKDOWN_REPORT"
    echo "markdown report head:"
    print_head "$MARKDOWN_REPORT"
    echo
    echo "Failure Context"
    echo "current scenario: $CURRENT_SCENARIO"
    echo "last typed topic list:"
    print_head "$CURRENT_TOPIC_LIST"
    echo "last fake sensor launch log tail:"
    print_tail "$CURRENT_FAKE_LOG"
    echo "last processor launch log tail:"
    print_tail "$CURRENT_PROCESSOR_LOG"
    echo "last system metrics launch log tail:"
    print_tail "$CURRENT_SYSTEM_LOG"
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
    echo "$QOS_BAG_DIR"
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

printf 'scenario_name,scenario_kind,frequency_hz,sensor_qos_reliability,processor_qos_reliability,qos_depth,receive_rate_hz,target_ratio,rate_gap_hz,drop_rate,average_latency_ms,p95_latency_ms,p99_latency_ms,cpu_percent,memory_used_mb,memory_total_mb,temperature_c,metrics_messages,received_count,expected_count,dropped_count,notes\n' > "$CSV_PATH"

for hz in 500 1000; do
  for reliability in best_effort reliable; do
    for depth in 10 50; do
      run_pressure_scenario "$hz" "$reliability" "$reliability" "$depth" "pressure"
    done
  done

  run_pressure_scenario "$hz" "best_effort" "reliable" 10 "qos_mismatch"
done

if [[ "$SCENARIO_COUNT" -ne 10 ]]; then
  fail "expected 10 P0-014 scenarios, got $SCENARIO_COUNT"
fi

if [[ "$PRESSURE_SCENARIO_COUNT" -ne 8 ]]; then
  fail "expected 8 pressure scenarios, got $PRESSURE_SCENARIO_COUNT"
fi

if [[ "$MISMATCH_SCENARIO_COUNT" -ne 2 ]]; then
  fail "expected 2 QoS mismatch scenarios, got $MISMATCH_SCENARIO_COUNT"
fi

CSV_ROWS="$(($(wc -l < "$CSV_PATH") - 1))"
if [[ "$CSV_ROWS" -ne 10 ]]; then
  fail "expected 10 CSV data rows, got $CSV_ROWS"
fi

for required in "500,best_effort" "500,reliable" "1000,best_effort" "1000,reliable"; do
  IFS=, read -r required_hz required_reliability <<< "$required"
  if ! awk -F, -v hz="$required_hz" -v reliability="$required_reliability" \
    'NR > 1 && $2 == "pressure" && $3 == hz && $4 == reliability && $5 == reliability { found = 1 } END { exit !found }' "$CSV_PATH"; then
    fail "missing pressure CSV scenario for ${required_hz}Hz ${required_reliability}"
  fi
done

for required_hz in 500 1000; do
  if ! awk -F, -v hz="$required_hz" \
    'NR > 1 && $2 == "qos_mismatch" && $3 == hz && $4 == "best_effort" && $5 == "reliable" && $19 == "0" { found = 1 } END { exit !found }' "$CSV_PATH"; then
    fail "missing reproduced QoS mismatch CSV scenario for ${required_hz}Hz"
  fi
done

write_markdown_report
collect_git_status
write_report
