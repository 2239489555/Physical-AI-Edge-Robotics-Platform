#include <array>
#include <chrono>
#include <cstdio>
#include <filesystem>
#include <fstream>
#include <memory>
#include <string>
#include <vector>

#include "edge_reliability_msgs/msg/system_metrics.hpp"
#include "edge_reliability_system/tegrastats_parser.hpp"
#include "rclcpp/rclcpp.hpp"

namespace edge_reliability_system
{

class SystemMetricsNode : public rclcpp::Node
{
public:
  SystemMetricsNode()
  : rclcpp::Node("system_metrics_node")
  {
    metrics_topic_ = declare_parameter<std::string>("metrics_topic", "/edge/metrics/system");
    frame_id_ = declare_parameter<std::string>("frame_id", "system_metrics_frame");
    input_mode_ = declare_parameter<std::string>("input_mode", "sample_file");
    sample_file_ = declare_parameter<std::string>("sample_file", "");
    live_command_ =
      declare_parameter<std::string>("live_command", "timeout 2s tegrastats --interval 1000");
    publish_hz_ = declare_parameter<double>("publish_hz", 1.0);
    qos_depth_ = declare_parameter<int>("qos_depth", 10);
    raw_log_enabled_ = declare_parameter<bool>("raw_log_enabled", true);
    raw_log_path_ = declare_parameter<std::string>(
      "raw_log_path",
      "../runtime/logs/tegrastats/system_metrics_node_raw.log");

    normalize_parameters();
    load_sample_lines();
    prepare_raw_log();

    const auto qos = rclcpp::QoS(static_cast<size_t>(qos_depth_)).reliable();
    publisher_ = create_publisher<edge_reliability_msgs::msg::SystemMetrics>(metrics_topic_, qos);
    timer_ = create_wall_timer(
      std::chrono::duration<double>(1.0 / publish_hz_),
      [this]() {
        publish_once();
      });

    RCLCPP_INFO(
      get_logger(),
      "event=startup node=system_metrics_node topic=%s "
      "type=edge_reliability_msgs/msg/SystemMetrics input_mode=%s sample_file=%s "
      "live_command=%s publish_hz=%.3f qos_depth=%d raw_log_enabled=%s raw_log_path=%s",
      metrics_topic_.c_str(),
      input_mode_.c_str(),
      sample_file_.empty() ? "(empty)" : sample_file_.c_str(),
      live_command_.c_str(),
      publish_hz_,
      qos_depth_,
      raw_log_enabled_ ? "true" : "false",
      raw_log_path_.c_str());
  }

  ~SystemMetricsNode() override
  {
    RCLCPP_INFO(
      get_logger(),
      "event=shutdown node=system_metrics_node reason=node_destroyed published_count=%lu",
      static_cast<unsigned long>(published_count_));
  }

private:
  void normalize_parameters()
  {
    if (publish_hz_ <= 0.0) {
      RCLCPP_WARN(
        get_logger(),
        "event=parameter_fallback parameter=publish_hz value=%.3f fallback=1.0",
        publish_hz_);
      publish_hz_ = 1.0;
    }

    if (qos_depth_ <= 0) {
      RCLCPP_WARN(
        get_logger(),
        "event=parameter_fallback parameter=qos_depth value=%d fallback=10",
        qos_depth_);
      qos_depth_ = 10;
    }

    if (input_mode_ != "sample_file" && input_mode_ != "live_command") {
      RCLCPP_WARN(
        get_logger(),
        "event=parameter_fallback parameter=input_mode value=%s fallback=sample_file",
        input_mode_.c_str());
      input_mode_ = "sample_file";
    }
  }

  void load_sample_lines()
  {
    if (sample_file_.empty()) {
      return;
    }

    std::ifstream input(sample_file_);
    if (!input.is_open()) {
      RCLCPP_WARN(
        get_logger(),
        "event=sample_file_unavailable path=%s",
        sample_file_.c_str());
      return;
    }

    std::string line;
    while (std::getline(input, line)) {
      if (!trim(line).empty()) {
        sample_lines_.push_back(line);
      }
    }

    RCLCPP_INFO(
      get_logger(),
      "event=sample_file_loaded path=%s line_count=%lu",
      sample_file_.c_str(),
      static_cast<unsigned long>(sample_lines_.size()));
  }

  void prepare_raw_log()
  {
    if (!raw_log_enabled_) {
      return;
    }

    const std::filesystem::path path(raw_log_path_);
    if (path.has_parent_path()) {
      std::filesystem::create_directories(path.parent_path());
    }

    std::ofstream output(raw_log_path_, std::ios::app);
    if (!output.is_open()) {
      RCLCPP_WARN(
        get_logger(),
        "event=raw_log_unavailable path=%s",
        raw_log_path_.c_str());
      raw_log_enabled_ = false;
    }
  }

  std::string read_next_raw_line()
  {
    if (input_mode_ == "sample_file") {
      if (sample_lines_.empty()) {
        return "";
      }

      const auto line = sample_lines_[sample_index_ % sample_lines_.size()];
      ++sample_index_;
      return line;
    }

    return run_live_command();
  }

  std::string run_live_command()
  {
    std::array<char, 512> buffer{};
    std::string last_line;
    FILE * pipe = popen(live_command_.c_str(), "r");
    if (pipe == nullptr) {
      RCLCPP_WARN(get_logger(), "event=live_command_start_failed command=%s", live_command_.c_str());
      return "";
    }

    while (fgets(buffer.data(), static_cast<int>(buffer.size()), pipe) != nullptr) {
      const auto line = trim(buffer.data());
      if (!line.empty()) {
        last_line = line;
      }
    }

    const auto status = pclose(pipe);
    if (status != 0 && last_line.empty()) {
      RCLCPP_WARN(
        get_logger(),
        "event=live_command_failed command=%s status=%d",
        live_command_.c_str(),
        status);
    }

    return last_line;
  }

  void append_raw_log(const std::string & line)
  {
    if (!raw_log_enabled_ || line.empty()) {
      return;
    }

    std::ofstream output(raw_log_path_, std::ios::app);
    if (output.is_open()) {
      output << line << '\n';
    }
  }

  void publish_once()
  {
    const auto line = read_next_raw_line();
    if (line.empty()) {
      if (!logged_empty_input_) {
        RCLCPP_WARN(
          get_logger(),
          "event=no_tegrastats_input input_mode=%s sample_file=%s",
          input_mode_.c_str(),
          sample_file_.c_str());
        logged_empty_input_ = true;
      }
      return;
    }

    append_raw_log(line);

    const auto parsed = parse_tegrastats_line(line);
    if (!parsed) {
      RCLCPP_WARN(get_logger(), "event=parse_failed raw_line=%s", line.c_str());
      return;
    }

    edge_reliability_msgs::msg::SystemMetrics message;
    message.header.stamp = now();
    message.header.frame_id = frame_id_;
    message.cpu_percent = parsed->cpu_percent;
    message.memory_used_mb = parsed->ram_used_mb;
    message.memory_total_mb = parsed->ram_total_mb;
    message.gpu_percent = parsed->gpu_percent;
    message.temperature_c = parsed->temperature_c;
    message.power_w = parsed->power_w;
    message.source = input_mode_ == "sample_file" ? "tegrastats_sample_file" : "tegrastats_live_command";

    publisher_->publish(message);
    ++published_count_;

    if (!logged_first_publish_) {
      RCLCPP_INFO(
        get_logger(),
        "event=first_publish cpu_percent=%.3f memory_used_mb=%.3f memory_total_mb=%.3f "
        "gpu_percent=%.3f temperature_c=%.3f power_w=%.3f source=%s",
        message.cpu_percent,
        message.memory_used_mb,
        message.memory_total_mb,
        message.gpu_percent,
        message.temperature_c,
        message.power_w,
        message.source.c_str());
      logged_first_publish_ = true;
    }
  }

  rclcpp::Publisher<edge_reliability_msgs::msg::SystemMetrics>::SharedPtr publisher_;
  rclcpp::TimerBase::SharedPtr timer_;
  std::vector<std::string> sample_lines_;
  std::string metrics_topic_{"/edge/metrics/system"};
  std::string frame_id_{"system_metrics_frame"};
  std::string input_mode_{"sample_file"};
  std::string sample_file_{};
  std::string live_command_{"timeout 2s tegrastats --interval 1000"};
  std::string raw_log_path_{"../runtime/logs/tegrastats/system_metrics_node_raw.log"};
  double publish_hz_{1.0};
  int qos_depth_{10};
  size_t sample_index_{0};
  uint64_t published_count_{0};
  bool raw_log_enabled_{true};
  bool logged_empty_input_{false};
  bool logged_first_publish_{false};
};

}  // namespace edge_reliability_system

int main(int argc, char ** argv)
{
  rclcpp::init(argc, argv);
  rclcpp::spin(std::make_shared<edge_reliability_system::SystemMetricsNode>());
  rclcpp::shutdown();
  return 0;
}
