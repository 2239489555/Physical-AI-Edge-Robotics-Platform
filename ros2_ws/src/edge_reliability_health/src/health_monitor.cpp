#include <algorithm>
#include <cstdint>
#include <memory>
#include <string>
#include <vector>

#include "edge_reliability_health/health_rules.hpp"
#include "edge_reliability_msgs/msg/health_state.hpp"
#include "edge_reliability_msgs/msg/pipeline_metrics.hpp"
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
    const auto min_expected_count = declare_parameter<int>("min_expected_count", 10);
    if (min_expected_count < 0) {
      RCLCPP_WARN(
        get_logger(),
        "event=parameter_fallback parameter=min_expected_count value=%d fallback=10",
        min_expected_count);
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

    RCLCPP_INFO(
      get_logger(),
      "event=startup node=health_monitor metrics_topic=%s "
      "metrics_type=edge_reliability_msgs/msg/PipelineMetrics health_topic=%s "
      "health_type=edge_reliability_msgs/msg/HealthState qos_depth=%d "
      "min_receive_rate_hz_warning=%.3f min_receive_rate_hz_unhealthy=%.3f "
      "max_drop_rate_warning=%.6f max_drop_rate_unhealthy=%.6f "
      "max_p95_latency_ms_warning=%.3f max_p95_latency_ms_unhealthy=%.3f "
      "max_p99_latency_ms_warning=%.3f max_p99_latency_ms_unhealthy=%.3f "
      "min_expected_count=%lu",
      metrics_topic_.c_str(),
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
    ++evaluated_count_;

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

    const auto evaluation = evaluate_pipeline_health(input, thresholds_);

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
  HealthThresholds thresholds_;
  std::string metrics_topic_{"/edge/metrics/pipeline"};
  std::string health_topic_{"/edge/health/state"};
  std::string frame_id_{"health_frame"};
  int qos_depth_{10};
  int last_state_{-1};
  uint64_t evaluated_count_{0};
  bool logged_first_metrics_{false};
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
