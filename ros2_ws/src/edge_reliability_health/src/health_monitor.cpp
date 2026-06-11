#include <algorithm>
#include <cstdint>
#include <memory>
#include <string>
#include <vector>

#include "edge_reliability_health/health_rules.hpp"
#include "edge_reliability_msgs/msg/health_state.hpp"
#include "edge_reliability_msgs/msg/pipeline_metrics.hpp"
#include "edge_reliability_msgs/msg/system_metrics.hpp"
#include "rclcpp/rclcpp.hpp"

namespace edge_reliability_health
{

class HealthMonitor : public rclcpp::Node
{
public:
  HealthMonitor()
  : rclcpp::Node("health_monitor")
  {
    metrics_topic_ = declare_parameter<std::string>("metrics_topic", "/edge/metrics/pipeline");
    system_metrics_topic_ =
      declare_parameter<std::string>("system_metrics_topic", "/edge/metrics/system");
    health_topic_ = declare_parameter<std::string>("health_topic", "/edge/health/state");
    frame_id_ = declare_parameter<std::string>("frame_id", "health_frame");
    qos_depth_ = declare_parameter<int>("qos_depth", 10);
    thresholds_.min_receive_rate_hz_warning =
      declare_parameter<double>("min_receive_rate_hz_warning", 95.0);
    thresholds_.min_receive_rate_hz_unhealthy =
      declare_parameter<double>("min_receive_rate_hz_unhealthy", 80.0);
    thresholds_.max_drop_rate_warning =
      declare_parameter<double>("max_drop_rate_warning", 0.001);
    thresholds_.max_drop_rate_unhealthy =
      declare_parameter<double>("max_drop_rate_unhealthy", 0.01);
    thresholds_.max_p95_latency_ms_warning =
      declare_parameter<double>("max_p95_latency_ms_warning", 5.0);
    thresholds_.max_p95_latency_ms_unhealthy =
      declare_parameter<double>("max_p95_latency_ms_unhealthy", 20.0);
    thresholds_.max_p99_latency_ms_warning =
      declare_parameter<double>("max_p99_latency_ms_warning", 10.0);
    thresholds_.max_p99_latency_ms_unhealthy =
      declare_parameter<double>("max_p99_latency_ms_unhealthy", 50.0);
    thresholds_.max_cpu_percent_warning =
      declare_parameter<double>("max_cpu_percent_warning", 85.0);
    thresholds_.max_cpu_percent_unhealthy =
      declare_parameter<double>("max_cpu_percent_unhealthy", 95.0);
    thresholds_.max_memory_used_percent_warning =
      declare_parameter<double>("max_memory_used_percent_warning", 80.0);
    thresholds_.max_memory_used_percent_unhealthy =
      declare_parameter<double>("max_memory_used_percent_unhealthy", 95.0);
    thresholds_.max_disk_used_percent_warning =
      declare_parameter<double>("max_disk_used_percent_warning", 80.0);
    thresholds_.max_disk_used_percent_unhealthy =
      declare_parameter<double>("max_disk_used_percent_unhealthy", 95.0);
    thresholds_.max_gpu_percent_warning =
      declare_parameter<double>("max_gpu_percent_warning", 90.0);
    thresholds_.max_gpu_percent_unhealthy =
      declare_parameter<double>("max_gpu_percent_unhealthy", 98.0);
    thresholds_.max_temperature_c_warning =
      declare_parameter<double>("max_temperature_c_warning", 75.0);
    thresholds_.max_temperature_c_unhealthy =
      declare_parameter<double>("max_temperature_c_unhealthy", 85.0);
    thresholds_.max_power_w_warning =
      declare_parameter<double>("max_power_w_warning", 45.0);
    thresholds_.max_power_w_unhealthy =
      declare_parameter<double>("max_power_w_unhealthy", 60.0);
    const auto min_expected_count = declare_parameter<int>("min_expected_count", 10);
    if (min_expected_count < 0) {
      RCLCPP_WARN(
        get_logger(),
        "event=parameter_fallback parameter=min_expected_count value=%ld fallback=10",
        static_cast<long>(min_expected_count));
      thresholds_.min_expected_count = 10;
    } else {
      thresholds_.min_expected_count = static_cast<uint64_t>(min_expected_count);
    }

    normalize_parameters();

    const auto qos = rclcpp::QoS(static_cast<size_t>(qos_depth_)).reliable();
    health_publisher_ =
      create_publisher<edge_reliability_msgs::msg::HealthState>(health_topic_, qos);
    metrics_subscription_ =
      create_subscription<edge_reliability_msgs::msg::PipelineMetrics>(
      metrics_topic_,
      qos,
      [this](edge_reliability_msgs::msg::PipelineMetrics::SharedPtr message) {
        on_pipeline_metrics(message);
      });
    system_metrics_subscription_ =
      create_subscription<edge_reliability_msgs::msg::SystemMetrics>(
      system_metrics_topic_,
      qos,
      [this](edge_reliability_msgs::msg::SystemMetrics::SharedPtr message) {
        on_system_metrics(message);
      });

    RCLCPP_INFO(
      get_logger(),
      "event=startup node=health_monitor metrics_topic=%s "
      "metrics_type=edge_reliability_msgs/msg/PipelineMetrics system_metrics_topic=%s "
      "system_metrics_type=edge_reliability_msgs/msg/SystemMetrics health_topic=%s "
      "health_type=edge_reliability_msgs/msg/HealthState qos_depth=%d "
      "min_receive_rate_hz_warning=%.3f min_receive_rate_hz_unhealthy=%.3f "
      "max_drop_rate_warning=%.6f max_drop_rate_unhealthy=%.6f "
      "max_p95_latency_ms_warning=%.3f max_p95_latency_ms_unhealthy=%.3f "
      "max_p99_latency_ms_warning=%.3f max_p99_latency_ms_unhealthy=%.3f "
      "max_cpu_percent_warning=%.3f max_cpu_percent_unhealthy=%.3f "
      "max_memory_used_percent_warning=%.3f max_memory_used_percent_unhealthy=%.3f "
      "max_disk_used_percent_warning=%.3f max_disk_used_percent_unhealthy=%.3f "
      "max_gpu_percent_warning=%.3f max_gpu_percent_unhealthy=%.3f "
      "max_temperature_c_warning=%.3f max_temperature_c_unhealthy=%.3f "
      "max_power_w_warning=%.3f max_power_w_unhealthy=%.3f "
      "min_expected_count=%lu",
      metrics_topic_.c_str(),
      system_metrics_topic_.c_str(),
      health_topic_.c_str(),
      qos_depth_,
      thresholds_.min_receive_rate_hz_warning,
      thresholds_.min_receive_rate_hz_unhealthy,
      thresholds_.max_drop_rate_warning,
      thresholds_.max_drop_rate_unhealthy,
      thresholds_.max_p95_latency_ms_warning,
      thresholds_.max_p95_latency_ms_unhealthy,
      thresholds_.max_p99_latency_ms_warning,
      thresholds_.max_p99_latency_ms_unhealthy,
      thresholds_.max_cpu_percent_warning,
      thresholds_.max_cpu_percent_unhealthy,
      thresholds_.max_memory_used_percent_warning,
      thresholds_.max_memory_used_percent_unhealthy,
      thresholds_.max_disk_used_percent_warning,
      thresholds_.max_disk_used_percent_unhealthy,
      thresholds_.max_gpu_percent_warning,
      thresholds_.max_gpu_percent_unhealthy,
      thresholds_.max_temperature_c_warning,
      thresholds_.max_temperature_c_unhealthy,
      thresholds_.max_power_w_warning,
      thresholds_.max_power_w_unhealthy,
      static_cast<unsigned long>(thresholds_.min_expected_count));
  }

  ~HealthMonitor() override
  {
    RCLCPP_INFO(
      get_logger(),
      "event=shutdown node=health_monitor reason=node_destroyed evaluated_count=%lu",
      static_cast<unsigned long>(evaluated_count_));
  }

private:
  void normalize_parameters()
  {
    if (qos_depth_ <= 0) {
      RCLCPP_WARN(
        get_logger(),
        "event=parameter_fallback parameter=qos_depth value=%d fallback=10",
        qos_depth_);
      qos_depth_ = 10;
    }

    clamp_min("min_receive_rate_hz_warning", thresholds_.min_receive_rate_hz_warning, 0.0);
    clamp_min("min_receive_rate_hz_unhealthy", thresholds_.min_receive_rate_hz_unhealthy, 0.0);
    clamp_min("max_drop_rate_warning", thresholds_.max_drop_rate_warning, 0.0);
    clamp_min("max_drop_rate_unhealthy", thresholds_.max_drop_rate_unhealthy, 0.0);
    clamp_min("max_p95_latency_ms_warning", thresholds_.max_p95_latency_ms_warning, 0.0);
    clamp_min("max_p95_latency_ms_unhealthy", thresholds_.max_p95_latency_ms_unhealthy, 0.0);
    clamp_min("max_p99_latency_ms_warning", thresholds_.max_p99_latency_ms_warning, 0.0);
    clamp_min("max_p99_latency_ms_unhealthy", thresholds_.max_p99_latency_ms_unhealthy, 0.0);
    clamp_min("max_cpu_percent_warning", thresholds_.max_cpu_percent_warning, 0.0);
    clamp_min("max_cpu_percent_unhealthy", thresholds_.max_cpu_percent_unhealthy, 0.0);
    clamp_min(
      "max_memory_used_percent_warning", thresholds_.max_memory_used_percent_warning, 0.0);
    clamp_min(
      "max_memory_used_percent_unhealthy", thresholds_.max_memory_used_percent_unhealthy, 0.0);
    clamp_min("max_disk_used_percent_warning", thresholds_.max_disk_used_percent_warning, 0.0);
    clamp_min(
      "max_disk_used_percent_unhealthy", thresholds_.max_disk_used_percent_unhealthy, 0.0);
    clamp_min("max_gpu_percent_warning", thresholds_.max_gpu_percent_warning, 0.0);
    clamp_min("max_gpu_percent_unhealthy", thresholds_.max_gpu_percent_unhealthy, 0.0);
    clamp_min("max_temperature_c_warning", thresholds_.max_temperature_c_warning, 0.0);
    clamp_min("max_temperature_c_unhealthy", thresholds_.max_temperature_c_unhealthy, 0.0);
    clamp_min("max_power_w_warning", thresholds_.max_power_w_warning, 0.0);
    clamp_min("max_power_w_unhealthy", thresholds_.max_power_w_unhealthy, 0.0);

    if (thresholds_.min_receive_rate_hz_unhealthy > thresholds_.min_receive_rate_hz_warning) {
      RCLCPP_WARN(
        get_logger(),
        "event=parameter_fallback parameter=min_receive_rate_hz_unhealthy value=%.3f "
        "fallback=%.3f",
        thresholds_.min_receive_rate_hz_unhealthy,
        thresholds_.min_receive_rate_hz_warning);
      thresholds_.min_receive_rate_hz_unhealthy = thresholds_.min_receive_rate_hz_warning;
    }

    ensure_max_unhealthy_at_least_warning(
      "max_drop_rate", thresholds_.max_drop_rate_warning, thresholds_.max_drop_rate_unhealthy);
    ensure_max_unhealthy_at_least_warning(
      "max_p95_latency_ms",
      thresholds_.max_p95_latency_ms_warning,
      thresholds_.max_p95_latency_ms_unhealthy);
    ensure_max_unhealthy_at_least_warning(
      "max_p99_latency_ms",
      thresholds_.max_p99_latency_ms_warning,
      thresholds_.max_p99_latency_ms_unhealthy);
    ensure_max_unhealthy_at_least_warning(
      "max_cpu_percent",
      thresholds_.max_cpu_percent_warning,
      thresholds_.max_cpu_percent_unhealthy);
    ensure_max_unhealthy_at_least_warning(
      "max_memory_used_percent",
      thresholds_.max_memory_used_percent_warning,
      thresholds_.max_memory_used_percent_unhealthy);
    ensure_max_unhealthy_at_least_warning(
      "max_disk_used_percent",
      thresholds_.max_disk_used_percent_warning,
      thresholds_.max_disk_used_percent_unhealthy);
    ensure_max_unhealthy_at_least_warning(
      "max_gpu_percent", thresholds_.max_gpu_percent_warning, thresholds_.max_gpu_percent_unhealthy);
    ensure_max_unhealthy_at_least_warning(
      "max_temperature_c",
      thresholds_.max_temperature_c_warning,
      thresholds_.max_temperature_c_unhealthy);
    ensure_max_unhealthy_at_least_warning(
      "max_power_w", thresholds_.max_power_w_warning, thresholds_.max_power_w_unhealthy);
  }

  void clamp_min(const char * parameter, double & value, double minimum)
  {
    if (value < minimum) {
      RCLCPP_WARN(
        get_logger(),
        "event=parameter_fallback parameter=%s value=%.3f fallback=%.3f",
        parameter,
        value,
        minimum);
      value = minimum;
    }
  }

  void ensure_max_unhealthy_at_least_warning(
    const char * prefix,
    double warning,
    double & unhealthy)
  {
    if (unhealthy < warning) {
      RCLCPP_WARN(
        get_logger(),
        "event=parameter_fallback parameter=%s_unhealthy value=%.3f fallback=%.3f",
        prefix,
        unhealthy,
        warning);
      unhealthy = warning;
    }
  }

  void on_pipeline_metrics(const edge_reliability_msgs::msg::PipelineMetrics::SharedPtr message)
  {
    if (!logged_first_metrics_) {
      RCLCPP_INFO(
        get_logger(),
        "event=first_metrics_receive received_count=%lu expected_count=%lu drop_rate=%.6f "
        "p95_latency_ms=%.3f p99_latency_ms=%.3f",
        static_cast<unsigned long>(message->received_count),
        static_cast<unsigned long>(message->expected_count),
        message->drop_rate,
        message->p95_latency_ms,
        message->p99_latency_ms);
      logged_first_metrics_ = true;
    }

    PipelineHealthInput input;
    input.received_count = message->received_count;
    input.expected_count = message->expected_count;
    input.dropped_count = message->dropped_count;
    input.out_of_order_count = message->out_of_order_count;
    input.receive_rate_hz = message->receive_rate_hz;
    input.p95_latency_ms = message->p95_latency_ms;
    input.p99_latency_ms = message->p99_latency_ms;
    input.drop_rate = message->drop_rate;
    latest_pipeline_input_ = input;
    has_pipeline_metrics_ = true;

    publish_health();
  }

  void on_system_metrics(const edge_reliability_msgs::msg::SystemMetrics::SharedPtr message)
  {
    if (!logged_first_system_metrics_) {
      RCLCPP_INFO(
        get_logger(),
        "event=first_system_metrics_receive cpu_percent=%.3f memory_used_mb=%.3f "
        "memory_total_mb=%.3f disk_used_percent=%.3f gpu_percent=%.3f "
        "temperature_c=%.3f power_w=%.3f source=%s",
        message->cpu_percent,
        message->memory_used_mb,
        message->memory_total_mb,
        message->disk_used_percent,
        message->gpu_percent,
        message->temperature_c,
        message->power_w,
        message->source.c_str());
      logged_first_system_metrics_ = true;
    }

    SystemHealthInput input;
    input.available = true;
    input.cpu_percent = message->cpu_percent;
    input.memory_used_mb = message->memory_used_mb;
    input.memory_total_mb = message->memory_total_mb;
    input.disk_used_percent = message->disk_used_percent;
    input.gpu_percent = message->gpu_percent;
    input.temperature_c = message->temperature_c;
    input.power_w = message->power_w;
    latest_system_input_ = input;
    has_system_metrics_ = true;

    publish_health();
  }

  void publish_health()
  {
    ++evaluated_count_;

    const auto pipeline_evaluation =
      evaluate_pipeline_health(latest_pipeline_input_, thresholds_);
    const auto system_evaluation =
      evaluate_system_health(latest_system_input_, thresholds_);
    const auto evaluation = combine_health_evaluations(
      pipeline_evaluation,
      has_pipeline_metrics_,
      system_evaluation,
      has_system_metrics_);

    edge_reliability_msgs::msg::HealthState health;
    health.header.stamp = now();
    health.header.frame_id = frame_id_;
    health.state = evaluation.state;
    health.reason = evaluation.reason;
    health.active_rules = evaluation.active_rules;
    health_publisher_->publish(health);

    if (!logged_first_health_) {
      RCLCPP_INFO(
        get_logger(),
        "event=first_health_publish state=%s reason=%s active_rules=%s",
        state_name(evaluation.state).c_str(),
        evaluation.reason.c_str(),
        join_rules(evaluation.active_rules).c_str());
      logged_first_health_ = true;
    }

    if (last_state_ < 0 || static_cast<uint8_t>(last_state_) != evaluation.state) {
      RCLCPP_INFO(
        get_logger(),
        "event=health_transition previous_state=%s state=%s reason=%s active_rules=%s",
        last_state_ < 0 ? "NONE" : state_name(static_cast<uint8_t>(last_state_)).c_str(),
        state_name(evaluation.state).c_str(),
        evaluation.reason.c_str(),
        join_rules(evaluation.active_rules).c_str());
      last_state_ = static_cast<int>(evaluation.state);
    }
  }

  static std::string state_name(uint8_t state)
  {
    switch (state) {
      case edge_reliability_msgs::msg::HealthState::HEALTHY:
        return "HEALTHY";
      case edge_reliability_msgs::msg::HealthState::WARNING:
        return "WARNING";
      case edge_reliability_msgs::msg::HealthState::UNHEALTHY:
        return "UNHEALTHY";
      default:
        return "UNKNOWN";
    }
  }

  rclcpp::Publisher<edge_reliability_msgs::msg::HealthState>::SharedPtr health_publisher_;
  rclcpp::Subscription<edge_reliability_msgs::msg::PipelineMetrics>::SharedPtr metrics_subscription_;
  rclcpp::Subscription<edge_reliability_msgs::msg::SystemMetrics>::SharedPtr
    system_metrics_subscription_;
  HealthThresholds thresholds_;
  PipelineHealthInput latest_pipeline_input_;
  SystemHealthInput latest_system_input_;
  std::string metrics_topic_{"/edge/metrics/pipeline"};
  std::string system_metrics_topic_{"/edge/metrics/system"};
  std::string health_topic_{"/edge/health/state"};
  std::string frame_id_{"health_frame"};
  int qos_depth_{10};
  int last_state_{-1};
  uint64_t evaluated_count_{0};
  bool has_pipeline_metrics_{false};
  bool has_system_metrics_{false};
  bool logged_first_metrics_{false};
  bool logged_first_system_metrics_{false};
  bool logged_first_health_{false};
};

}  // namespace edge_reliability_health

int main(int argc, char ** argv)
{
  rclcpp::init(argc, argv);
  rclcpp::spin(std::make_shared<edge_reliability_health::HealthMonitor>());
  rclcpp::shutdown();
  return 0;
}
