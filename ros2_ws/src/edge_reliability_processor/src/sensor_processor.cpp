#include <chrono>
#include <cstdint>
#include <functional>
#include <memory>
#include <string>
#include <thread>

#include "builtin_interfaces/msg/time.hpp"
#include "edge_reliability_msgs/msg/pipeline_metrics.hpp"
#include "edge_reliability_msgs/msg/sensor_sample.hpp"
#include "edge_reliability_processor/pipeline_metrics_accumulator.hpp"
#include "rclcpp/rclcpp.hpp"

namespace edge_reliability_processor
{

class SensorProcessor : public rclcpp::Node
{
public:
  SensorProcessor()
  : Node("sensor_processor")
  {
    sensor_topic_ = declare_parameter<std::string>("sensor_topic", "/edge/sensors/fake_primary");
    metrics_topic_ = declare_parameter<std::string>("metrics_topic", "/edge/metrics/pipeline");
    metrics_frame_id_ = declare_parameter<std::string>("metrics_frame_id", "pipeline_metrics_frame");
    expected_hz_ = declare_parameter<double>("expected_hz", 100.0);
    metrics_publish_hz_ = declare_parameter<double>("metrics_publish_hz", 1.0);
    latency_warn_ms_ = declare_parameter<double>("latency_warn_ms", 20.0);
    latency_unhealthy_ms_ = declare_parameter<double>("latency_unhealthy_ms", 50.0);
    sensor_qos_depth_ = declare_parameter<int>("sensor_qos_depth", 10);
    sensor_qos_reliability_ = declare_parameter<std::string>("sensor_qos_reliability", "best_effort");
    metrics_qos_depth_ = declare_parameter<int>("metrics_qos_depth", 10);
    rate_window_seconds_ = declare_parameter<double>("rate_window_seconds", 5.0);
    latency_window_size_ = declare_parameter<int>("latency_window_size", 1000);
    processing_delay_enabled_ = declare_parameter<bool>("processing_delay_enabled", false);
    processing_delay_ms_ = declare_parameter<double>("processing_delay_ms", 0.0);

    normalize_parameters();
    accumulator_.configure(expected_hz_, rate_window_seconds_, latency_window_size_);

    auto sensor_qos = rclcpp::QoS(rclcpp::KeepLast(static_cast<size_t>(sensor_qos_depth_)));
    if (sensor_qos_reliability_ == "reliable") {
      sensor_qos.reliable();
    } else {
      sensor_qos.best_effort();
    }

    auto metrics_qos = rclcpp::QoS(rclcpp::KeepLast(static_cast<size_t>(metrics_qos_depth_)));
    metrics_qos.reliable();

    metrics_publisher_ =
      create_publisher<edge_reliability_msgs::msg::PipelineMetrics>(metrics_topic_, metrics_qos);
    sensor_subscription_ = create_subscription<edge_reliability_msgs::msg::SensorSample>(
      sensor_topic_,
      sensor_qos,
      std::bind(&SensorProcessor::on_sensor_sample, this, std::placeholders::_1));

    const auto period = std::chrono::duration_cast<std::chrono::nanoseconds>(
      std::chrono::duration<double>(1.0 / metrics_publish_hz_));
    metrics_timer_ = create_wall_timer(period, std::bind(&SensorProcessor::publish_metrics, this));

    RCLCPP_INFO(
      get_logger(),
      "event=startup node=sensor_processor sensor_topic=%s sensor_type=edge_reliability_msgs/msg/SensorSample "
      "metrics_topic=%s metrics_type=edge_reliability_msgs/msg/PipelineMetrics expected_hz=%.3f "
      "metrics_publish_hz=%.3f sensor_qos_depth=%d sensor_qos_reliability=%s "
      "metrics_qos_depth=%d metrics_qos_reliability=reliable rate_window_seconds=%.3f "
      "latency_window_size=%d latency_warn_ms=%.3f latency_unhealthy_ms=%.3f "
      "processing_delay_enabled=%s processing_delay_ms=%.3f",
      sensor_topic_.c_str(),
      metrics_topic_.c_str(),
      expected_hz_,
      metrics_publish_hz_,
      sensor_qos_depth_,
      sensor_qos_reliability_.c_str(),
      metrics_qos_depth_,
      rate_window_seconds_,
      latency_window_size_,
      latency_warn_ms_,
      latency_unhealthy_ms_,
      processing_delay_enabled_ ? "true" : "false",
      processing_delay_ms_);
  }

  ~SensorProcessor() override
  {
    const auto snapshot = accumulator_.snapshot(now().nanoseconds());
    RCLCPP_INFO(
      get_logger(),
      "event=shutdown node=sensor_processor reason=node_destroyed received_count=%lu dropped_count=%lu "
      "out_of_order_count=%lu",
      static_cast<unsigned long>(snapshot.received_count),
      static_cast<unsigned long>(snapshot.dropped_count),
      static_cast<unsigned long>(snapshot.out_of_order_count));
  }

private:
  void normalize_parameters()
  {
    if (sensor_topic_.empty()) {
      RCLCPP_WARN(
        get_logger(),
        "event=parameter_fallback parameter=sensor_topic fallback=/edge/sensors/fake_primary");
      sensor_topic_ = "/edge/sensors/fake_primary";
    }

    if (metrics_topic_.empty()) {
      RCLCPP_WARN(
        get_logger(),
        "event=parameter_fallback parameter=metrics_topic fallback=/edge/metrics/pipeline");
      metrics_topic_ = "/edge/metrics/pipeline";
    }

    if (metrics_frame_id_.empty()) {
      RCLCPP_WARN(
        get_logger(),
        "event=parameter_fallback parameter=metrics_frame_id fallback=pipeline_metrics_frame");
      metrics_frame_id_ = "pipeline_metrics_frame";
    }

    if (expected_hz_ <= 0.0) {
      RCLCPP_WARN(
        get_logger(),
        "event=parameter_fallback parameter=expected_hz value=%.3f fallback=100.0",
        expected_hz_);
      expected_hz_ = 100.0;
    }

    if (metrics_publish_hz_ <= 0.0) {
      RCLCPP_WARN(
        get_logger(),
        "event=parameter_fallback parameter=metrics_publish_hz value=%.3f fallback=1.0",
        metrics_publish_hz_);
      metrics_publish_hz_ = 1.0;
    }

    if (sensor_qos_depth_ < 1) {
      RCLCPP_WARN(
        get_logger(),
        "event=parameter_fallback parameter=sensor_qos_depth value=%d fallback=10",
        sensor_qos_depth_);
      sensor_qos_depth_ = 10;
    }

    if (sensor_qos_reliability_ != "best_effort" && sensor_qos_reliability_ != "reliable") {
      RCLCPP_WARN(
        get_logger(),
        "event=parameter_fallback parameter=sensor_qos_reliability value=%s fallback=best_effort",
        sensor_qos_reliability_.c_str());
      sensor_qos_reliability_ = "best_effort";
    }

    if (metrics_qos_depth_ < 1) {
      RCLCPP_WARN(
        get_logger(),
        "event=parameter_fallback parameter=metrics_qos_depth value=%d fallback=10",
        metrics_qos_depth_);
      metrics_qos_depth_ = 10;
    }

    if (rate_window_seconds_ <= 0.0) {
      RCLCPP_WARN(
        get_logger(),
        "event=parameter_fallback parameter=rate_window_seconds value=%.3f fallback=5.0",
        rate_window_seconds_);
      rate_window_seconds_ = 5.0;
    }

    if (latency_window_size_ < 1) {
      RCLCPP_WARN(
        get_logger(),
        "event=parameter_fallback parameter=latency_window_size value=%d fallback=1000",
        latency_window_size_);
      latency_window_size_ = 1000;
    }

    if (processing_delay_ms_ < 0.0) {
      RCLCPP_WARN(
        get_logger(),
        "event=parameter_fallback parameter=processing_delay_ms value=%.3f fallback=0.0",
        processing_delay_ms_);
      processing_delay_ms_ = 0.0;
    }

    if (processing_delay_ms_ == 0.0) {
      processing_delay_enabled_ = false;
    }
  }

  static int64_t stamp_to_nanoseconds(const builtin_interfaces::msg::Time & stamp)
  {
    return (static_cast<int64_t>(stamp.sec) * 1000000000LL) + static_cast<int64_t>(stamp.nanosec);
  }

  void on_sensor_sample(const edge_reliability_msgs::msg::SensorSample::SharedPtr message)
  {
    if (processing_delay_enabled_ && processing_delay_ms_ > 0.0) {
      if (!logged_first_processing_delay_) {
        RCLCPP_INFO(
          get_logger(),
          "event=first_processing_delay processing_delay_ms=%.3f",
          processing_delay_ms_);
        logged_first_processing_delay_ = true;
      }

      const auto delay = std::chrono::duration_cast<std::chrono::nanoseconds>(
        std::chrono::duration<double, std::milli>(processing_delay_ms_));
      std::this_thread::sleep_for(delay);
    }

    const auto receive_time = now();
    accumulator_.observe(
      message->sequence_id,
      stamp_to_nanoseconds(message->header.stamp),
      receive_time.nanoseconds());

    if (!logged_first_receive_) {
      RCLCPP_INFO(
        get_logger(),
        "event=first_receive sensor_topic=%s sequence_id=%lu sensor_id=%s stamp_sec=%d stamp_nanosec=%u",
        sensor_topic_.c_str(),
        static_cast<unsigned long>(message->sequence_id),
        message->sensor_id.c_str(),
        message->header.stamp.sec,
        message->header.stamp.nanosec);
      logged_first_receive_ = true;
    }
  }

  void publish_metrics()
  {
    const auto publish_time = now();
    const auto snapshot = accumulator_.snapshot(publish_time.nanoseconds());

    edge_reliability_msgs::msg::PipelineMetrics message;
    message.header.stamp = publish_time;
    message.header.frame_id = metrics_frame_id_;
    message.received_count = snapshot.received_count;
    message.expected_count = snapshot.expected_count;
    message.dropped_count = snapshot.dropped_count;
    message.out_of_order_count = snapshot.out_of_order_count;
    message.receive_rate_hz = snapshot.receive_rate_hz;
    message.expected_rate_hz = snapshot.expected_rate_hz;
    message.average_latency_ms = snapshot.average_latency_ms;
    message.p95_latency_ms = snapshot.p95_latency_ms;
    message.p99_latency_ms = snapshot.p99_latency_ms;
    message.drop_rate = snapshot.drop_rate;

    metrics_publisher_->publish(message);

    if (!logged_first_metrics_publish_) {
      RCLCPP_INFO(
        get_logger(),
        "event=first_metrics_publish metrics_topic=%s received_count=%lu expected_count=%lu "
        "receive_rate_hz=%.3f average_latency_ms=%.3f p95_latency_ms=%.3f p99_latency_ms=%.3f drop_rate=%.6f",
        metrics_topic_.c_str(),
        static_cast<unsigned long>(message.received_count),
        static_cast<unsigned long>(message.expected_count),
        message.receive_rate_hz,
        message.average_latency_ms,
        message.p95_latency_ms,
        message.p99_latency_ms,
        message.drop_rate);
      logged_first_metrics_publish_ = true;
    }
  }

  rclcpp::Subscription<edge_reliability_msgs::msg::SensorSample>::SharedPtr sensor_subscription_;
  rclcpp::Publisher<edge_reliability_msgs::msg::PipelineMetrics>::SharedPtr metrics_publisher_;
  rclcpp::TimerBase::SharedPtr metrics_timer_;
  PipelineMetricsAccumulator accumulator_;
  std::string sensor_topic_{"/edge/sensors/fake_primary"};
  std::string metrics_topic_{"/edge/metrics/pipeline"};
  std::string metrics_frame_id_{"pipeline_metrics_frame"};
  std::string sensor_qos_reliability_{"best_effort"};
  double expected_hz_{100.0};
  double metrics_publish_hz_{1.0};
  double latency_warn_ms_{20.0};
  double latency_unhealthy_ms_{50.0};
  double rate_window_seconds_{5.0};
  double processing_delay_ms_{0.0};
  int sensor_qos_depth_{10};
  int metrics_qos_depth_{10};
  int latency_window_size_{1000};
  bool processing_delay_enabled_{false};
  bool logged_first_receive_{false};
  bool logged_first_metrics_publish_{false};
  bool logged_first_processing_delay_{false};
};

}  // namespace edge_reliability_processor

int main(int argc, char ** argv)
{
  rclcpp::init(argc, argv);
  rclcpp::spin(std::make_shared<edge_reliability_processor::SensorProcessor>());
  rclcpp::shutdown();
  return 0;
}
