#include <chrono>
#include <cstdint>
#include <functional>
#include <memory>
#include <string>
#include <utility>

#include "edge_reliability_msgs/msg/sensor_sample.hpp"
#include "rclcpp/rclcpp.hpp"

namespace edge_reliability_fake_sensor
{

class FakeSensorAdapter : public rclcpp::Node
{
public:
  FakeSensorAdapter()
  : Node("fake_sensor_adapter")
  {
    publish_hz_ = declare_parameter<double>("publish_hz", 100.0);
    sensor_id_ = declare_parameter<std::string>("sensor_id", "fake_primary");
    frame_id_ = declare_parameter<std::string>("frame_id", "fake_sensor_frame");
    topic_ = declare_parameter<std::string>("topic", "/edge/sensors/fake_primary");
    status_mode_ = declare_parameter<std::string>("status_mode", "ok");
    fault_mode_ = declare_parameter<std::string>("fault_mode", "off");
    qos_depth_ = declare_parameter<int>("qos_depth", 10);
    qos_reliability_ = declare_parameter<std::string>("qos_reliability", "best_effort");

    normalize_parameters();

    const auto status = resolve_status(status_mode_);
    status_ = status.first;
    status_detail_ = status.second;

    auto qos = rclcpp::QoS(rclcpp::KeepLast(static_cast<size_t>(qos_depth_)));
    if (qos_reliability_ == "reliable") {
      qos.reliable();
    } else if (qos_reliability_ == "best_effort") {
      qos.best_effort();
    } else {
      RCLCPP_WARN(
        get_logger(),
        "event=parameter_fallback parameter=qos_reliability value=%s fallback=best_effort",
        qos_reliability_.c_str());
      qos_reliability_ = "best_effort";
      qos.best_effort();
    }

    publisher_ = create_publisher<edge_reliability_msgs::msg::SensorSample>(topic_, qos);

    const auto period = std::chrono::duration_cast<std::chrono::nanoseconds>(
      std::chrono::duration<double>(1.0 / publish_hz_));
    timer_ = create_wall_timer(period, std::bind(&FakeSensorAdapter::publish_sample, this));

    RCLCPP_INFO(
      get_logger(),
      "event=startup node=fake_sensor_adapter topic=%s type=edge_reliability_msgs/msg/SensorSample "
      "publish_hz=%.3f sensor_id=%s frame_id=%s status_mode=%s fault_mode=%s qos_depth=%d "
      "qos_reliability=%s",
      topic_.c_str(),
      publish_hz_,
      sensor_id_.c_str(),
      frame_id_.c_str(),
      status_mode_.c_str(),
      fault_mode_.c_str(),
      qos_depth_,
      qos_reliability_.c_str());
  }

  ~FakeSensorAdapter() override
  {
    RCLCPP_INFO(
      get_logger(),
      "event=shutdown node=fake_sensor_adapter reason=node_destroyed published_count=%lu",
      static_cast<unsigned long>(sequence_id_));
  }

private:
  void normalize_parameters()
  {
    if (publish_hz_ <= 0.0) {
      RCLCPP_WARN(
        get_logger(),
        "event=parameter_fallback parameter=publish_hz value=%.3f fallback=100.0",
        publish_hz_);
      publish_hz_ = 100.0;
    }

    if (sensor_id_.empty()) {
      RCLCPP_WARN(get_logger(), "event=parameter_fallback parameter=sensor_id fallback=fake_primary");
      sensor_id_ = "fake_primary";
    }

    if (frame_id_.empty()) {
      RCLCPP_WARN(get_logger(), "event=parameter_fallback parameter=frame_id fallback=fake_sensor_frame");
      frame_id_ = "fake_sensor_frame";
    }

    if (topic_.empty()) {
      RCLCPP_WARN(
        get_logger(),
        "event=parameter_fallback parameter=topic fallback=/edge/sensors/fake_primary");
      topic_ = "/edge/sensors/fake_primary";
    }

    if (qos_depth_ < 1) {
      RCLCPP_WARN(
        get_logger(),
        "event=parameter_fallback parameter=qos_depth value=%d fallback=10",
        qos_depth_);
      qos_depth_ = 10;
    }

    if (fault_mode_ != "off") {
      RCLCPP_WARN(
        get_logger(),
        "event=parameter_notice parameter=fault_mode value=%s note=fault_injection_is_deferred",
        fault_mode_.c_str());
    }
  }

  std::pair<uint8_t, std::string> resolve_status(const std::string & status_mode)
  {
    using edge_reliability_msgs::msg::SensorSample;

    if (status_mode == "ok") {
      return {SensorSample::STATUS_OK, "ok"};
    }

    if (status_mode == "warn") {
      return {SensorSample::STATUS_WARN, "configured warn status"};
    }

    if (status_mode == "error") {
      return {SensorSample::STATUS_ERROR, "configured error status"};
    }

    RCLCPP_WARN(
      get_logger(),
      "event=parameter_fallback parameter=status_mode value=%s fallback=warn",
      status_mode.c_str());
    status_mode_ = "warn";
    return {SensorSample::STATUS_WARN, "unknown status_mode"};
  }

  void publish_sample()
  {
    edge_reliability_msgs::msg::SensorSample message;
    message.header.stamp = now();
    message.header.frame_id = frame_id_;
    message.sequence_id = sequence_id_;
    message.sensor_id = sensor_id_;
    message.value = static_cast<double>(sequence_id_ % 1000U) / 1000.0;
    message.status = status_;
    message.status_detail = status_detail_;

    publisher_->publish(message);

    if (!logged_first_sample_) {
      RCLCPP_INFO(
        get_logger(),
        "event=first_publish topic=%s sequence_id=%lu stamp_sec=%d stamp_nanosec=%u",
        topic_.c_str(),
        static_cast<unsigned long>(message.sequence_id),
        message.header.stamp.sec,
        message.header.stamp.nanosec);
      logged_first_sample_ = true;
    }

    ++sequence_id_;
  }

  rclcpp::Publisher<edge_reliability_msgs::msg::SensorSample>::SharedPtr publisher_;
  rclcpp::TimerBase::SharedPtr timer_;
  double publish_hz_{100.0};
  std::string sensor_id_{"fake_primary"};
  std::string frame_id_{"fake_sensor_frame"};
  std::string topic_{"/edge/sensors/fake_primary"};
  std::string status_mode_{"ok"};
  std::string fault_mode_{"off"};
  int qos_depth_{10};
  std::string qos_reliability_{"best_effort"};
  uint64_t sequence_id_{0};
  uint8_t status_{edge_reliability_msgs::msg::SensorSample::STATUS_OK};
  std::string status_detail_{"ok"};
  bool logged_first_sample_{false};
};

}  // namespace edge_reliability_fake_sensor

int main(int argc, char ** argv)
{
  rclcpp::init(argc, argv);
  rclcpp::spin(std::make_shared<edge_reliability_fake_sensor::FakeSensorAdapter>());
  rclcpp::shutdown();
  return 0;
}
