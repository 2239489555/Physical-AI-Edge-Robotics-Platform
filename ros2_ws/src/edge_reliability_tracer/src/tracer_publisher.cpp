#include <algorithm>
#include <chrono>
#include <cstdint>
#include <memory>
#include <sstream>
#include <string>

#include "rclcpp/rclcpp.hpp"
#include "std_msgs/msg/string.hpp"

class TracerPublisher : public rclcpp::Node
{
public:
  TracerPublisher()
  : Node("tracer_publisher")
  {
    const auto topic = declare_parameter<std::string>("topic", "edge/tracer");
    const auto publish_hz = std::max(0.1, declare_parameter<double>("publish_hz", 10.0));

    publisher_ = create_publisher<std_msgs::msg::String>(topic, rclcpp::QoS(10));

    const auto period = std::chrono::duration_cast<std::chrono::nanoseconds>(
      std::chrono::duration<double>(1.0 / publish_hz));

    timer_ = create_wall_timer(period, [this]() {
      std_msgs::msg::String message;
      std::ostringstream payload;
      payload << "seq=" << sequence_ << " stamp_ns=" << now().nanoseconds();
      message.data = payload.str();
      publisher_->publish(message);
      RCLCPP_INFO(get_logger(), "Published tracer sample: '%s'", message.data.c_str());
      ++sequence_;
    });

    RCLCPP_INFO(
      get_logger(), "Publishing tracer samples on '%s' at %.2f Hz", topic.c_str(), publish_hz);
  }

private:
  rclcpp::Publisher<std_msgs::msg::String>::SharedPtr publisher_;
  rclcpp::TimerBase::SharedPtr timer_;
  std::uint64_t sequence_{0};
};

int main(int argc, char * argv[])
{
  rclcpp::init(argc, argv);
  rclcpp::spin(std::make_shared<TracerPublisher>());
  rclcpp::shutdown();
  return 0;
}
