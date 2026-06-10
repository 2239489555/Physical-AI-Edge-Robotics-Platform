#include <memory>
#include <string>

#include "rclcpp/rclcpp.hpp"
#include "std_msgs/msg/string.hpp"

class TracerSubscriber : public rclcpp::Node
{
public:
  TracerSubscriber()
  : Node("tracer_subscriber")
  {
    const auto topic = declare_parameter<std::string>("topic", "edge/tracer");

    subscription_ = create_subscription<std_msgs::msg::String>(
      topic, rclcpp::QoS(10), [this](const std_msgs::msg::String::SharedPtr message) {
        RCLCPP_INFO(get_logger(), "Received tracer sample: '%s'", message->data.c_str());
      });

    RCLCPP_INFO(get_logger(), "Listening for tracer samples on '%s'", topic.c_str());
  }

private:
  rclcpp::Subscription<std_msgs::msg::String>::SharedPtr subscription_;
};

int main(int argc, char * argv[])
{
  rclcpp::init(argc, argv);
  rclcpp::spin(std::make_shared<TracerSubscriber>());
  rclcpp::shutdown();
  return 0;
}
