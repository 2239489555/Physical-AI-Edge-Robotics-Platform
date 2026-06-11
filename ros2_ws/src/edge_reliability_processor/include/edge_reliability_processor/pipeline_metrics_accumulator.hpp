#ifndef EDGE_RELIABILITY_PROCESSOR__PIPELINE_METRICS_ACCUMULATOR_HPP_
#define EDGE_RELIABILITY_PROCESSOR__PIPELINE_METRICS_ACCUMULATOR_HPP_

#include <algorithm>
#include <cmath>
#include <cstdint>
#include <deque>
#include <vector>

namespace edge_reliability_processor
{

struct PipelineMetricsSnapshot
{
  uint64_t received_count{0};
  uint64_t expected_count{0};
  uint64_t dropped_count{0};
  uint64_t out_of_order_count{0};
  double receive_rate_hz{0.0};
  double expected_rate_hz{100.0};
  double average_latency_ms{0.0};
  double p95_latency_ms{0.0};
  double p99_latency_ms{0.0};
  double drop_rate{0.0};
};

class PipelineMetricsAccumulator
{
public:
  void configure(double expected_rate_hz, double rate_window_seconds, int latency_window_size)
  {
    expected_rate_hz_ = expected_rate_hz > 0.0 ? expected_rate_hz : 100.0;
    rate_window_ns_ = seconds_to_nanoseconds(rate_window_seconds > 0.0 ? rate_window_seconds : 5.0);
    latency_window_size_ = latency_window_size > 0 ? static_cast<size_t>(latency_window_size) : 1000U;
  }

  void observe(uint64_t sequence_id, int64_t sample_stamp_ns, int64_t receive_stamp_ns)
  {
    ++received_count_;

    if (!have_last_sequence_) {
      have_last_sequence_ = true;
      last_sequence_id_ = sequence_id;
    } else if (sequence_id <= last_sequence_id_) {
      ++out_of_order_count_;
    } else {
      if (sequence_id > last_sequence_id_ + 1U) {
        dropped_count_ += sequence_id - last_sequence_id_ - 1U;
      }
      last_sequence_id_ = sequence_id;
    }

    const double latency_ms = std::max(0.0, static_cast<double>(receive_stamp_ns - sample_stamp_ns) / 1000000.0);
    latencies_ms_.push_back(latency_ms);
    while (latencies_ms_.size() > latency_window_size_) {
      latencies_ms_.pop_front();
    }

    receive_times_ns_.push_back(receive_stamp_ns);
    trim_rate_window(receive_stamp_ns);
  }

  PipelineMetricsSnapshot snapshot(int64_t current_stamp_ns) const
  {
    PipelineMetricsSnapshot result;
    result.received_count = received_count_;
    result.dropped_count = dropped_count_;
    result.out_of_order_count = out_of_order_count_;
    result.expected_count = received_count_ + dropped_count_;
    result.expected_rate_hz = expected_rate_hz_;
    result.receive_rate_hz = receive_rate_hz(current_stamp_ns);
    result.average_latency_ms = average_latency_ms();
    result.p95_latency_ms = percentile_latency_ms(0.95);
    result.p99_latency_ms = percentile_latency_ms(0.99);
    result.drop_rate = result.expected_count == 0U ?
      0.0 :
      static_cast<double>(result.dropped_count) / static_cast<double>(result.expected_count);
    return result;
  }

private:
  static int64_t seconds_to_nanoseconds(double seconds)
  {
    return static_cast<int64_t>(seconds * 1000000000.0);
  }

  void trim_rate_window(int64_t current_stamp_ns)
  {
    while (!receive_times_ns_.empty() && current_stamp_ns - receive_times_ns_.front() > rate_window_ns_) {
      receive_times_ns_.pop_front();
    }
  }

  double receive_rate_hz(int64_t current_stamp_ns) const
  {
    (void)current_stamp_ns;

    if (receive_times_ns_.size() < 2U) {
      return 0.0;
    }

    const int64_t elapsed_ns = receive_times_ns_.back() - receive_times_ns_.front();
    if (elapsed_ns <= 0) {
      return 0.0;
    }

    return static_cast<double>(receive_times_ns_.size() - 1U) /
      (static_cast<double>(elapsed_ns) / 1000000000.0);
  }

  double average_latency_ms() const
  {
    if (latencies_ms_.empty()) {
      return 0.0;
    }

    double total = 0.0;
    for (const auto latency_ms : latencies_ms_) {
      total += latency_ms;
    }
    return total / static_cast<double>(latencies_ms_.size());
  }

  double percentile_latency_ms(double percentile) const
  {
    if (latencies_ms_.empty()) {
      return 0.0;
    }

    std::vector<double> sorted(latencies_ms_.begin(), latencies_ms_.end());
    std::sort(sorted.begin(), sorted.end());
    const auto index = static_cast<size_t>(
      std::ceil(percentile * static_cast<double>(sorted.size()))) - 1U;
    return sorted[std::min(index, sorted.size() - 1U)];
  }

  uint64_t received_count_{0};
  uint64_t dropped_count_{0};
  uint64_t out_of_order_count_{0};
  uint64_t last_sequence_id_{0};
  bool have_last_sequence_{false};
  double expected_rate_hz_{100.0};
  int64_t rate_window_ns_{5000000000LL};
  size_t latency_window_size_{1000U};
  std::deque<int64_t> receive_times_ns_;
  std::deque<double> latencies_ms_;
};

}  // namespace edge_reliability_processor

#endif  // EDGE_RELIABILITY_PROCESSOR__PIPELINE_METRICS_ACCUMULATOR_HPP_
