#ifndef EDGE_RELIABILITY_HEALTH__HEALTH_RULES_HPP_
#define EDGE_RELIABILITY_HEALTH__HEALTH_RULES_HPP_

#include <cstdint>
#include <string>
#include <vector>

namespace edge_reliability_health
{

struct HealthThresholds
{
  double min_receive_rate_hz_warning{95.0};
  double min_receive_rate_hz_unhealthy{80.0};
  double max_drop_rate_warning{0.001};
  double max_drop_rate_unhealthy{0.01};
  double max_p95_latency_ms_warning{5.0};
  double max_p95_latency_ms_unhealthy{20.0};
  double max_p99_latency_ms_warning{10.0};
  double max_p99_latency_ms_unhealthy{50.0};
  uint64_t min_expected_count{10};
};

struct PipelineHealthInput
{
  uint64_t received_count{0};
  uint64_t expected_count{0};
  uint64_t dropped_count{0};
  uint64_t out_of_order_count{0};
  double receive_rate_hz{0.0};
  double p95_latency_ms{0.0};
  double p99_latency_ms{0.0};
  double drop_rate{0.0};
};

struct HealthEvaluation
{
  uint8_t state{0};
  std::string reason{"healthy: pipeline metrics within thresholds"};
  std::vector<std::string> active_rules{};
};

namespace health_state
{
constexpr uint8_t HEALTHY = 0;
constexpr uint8_t WARNING = 1;
constexpr uint8_t UNHEALTHY = 2;
}  // namespace health_state

inline std::string join_rules(const std::vector<std::string> & rules)
{
  std::string result;
  for (const auto & rule : rules) {
    if (!result.empty()) {
      result += ",";
    }
    result += rule;
  }
  return result;
}

inline void add_rule(std::vector<std::string> & rules, const std::string & rule)
{
  rules.push_back(rule);
}

inline HealthEvaluation evaluate_pipeline_health(
  const PipelineHealthInput & input,
  const HealthThresholds & thresholds)
{
  std::vector<std::string> warning_rules;
  std::vector<std::string> unhealthy_rules;

  if (input.expected_count < thresholds.min_expected_count) {
    add_rule(warning_rules, "metrics_warmup");
  }

  if (input.receive_rate_hz < thresholds.min_receive_rate_hz_unhealthy) {
    add_rule(unhealthy_rules, "receive_rate_unhealthy");
  } else if (input.receive_rate_hz < thresholds.min_receive_rate_hz_warning) {
    add_rule(warning_rules, "receive_rate_warning");
  }

  if (input.drop_rate >= thresholds.max_drop_rate_unhealthy) {
    add_rule(unhealthy_rules, "drop_rate_unhealthy");
  } else if (input.drop_rate >= thresholds.max_drop_rate_warning) {
    add_rule(warning_rules, "drop_rate_warning");
  }

  if (input.p95_latency_ms >= thresholds.max_p95_latency_ms_unhealthy) {
    add_rule(unhealthy_rules, "p95_latency_unhealthy");
  } else if (input.p95_latency_ms >= thresholds.max_p95_latency_ms_warning) {
    add_rule(warning_rules, "p95_latency_warning");
  }

  if (input.p99_latency_ms >= thresholds.max_p99_latency_ms_unhealthy) {
    add_rule(unhealthy_rules, "p99_latency_unhealthy");
  } else if (input.p99_latency_ms >= thresholds.max_p99_latency_ms_warning) {
    add_rule(warning_rules, "p99_latency_warning");
  }

  if (input.out_of_order_count > 0U) {
    add_rule(unhealthy_rules, "out_of_order_unhealthy");
  }

  HealthEvaluation evaluation;
  if (!unhealthy_rules.empty()) {
    evaluation.state = health_state::UNHEALTHY;
    evaluation.active_rules = unhealthy_rules;
    evaluation.active_rules.insert(
      evaluation.active_rules.end(), warning_rules.begin(), warning_rules.end());
    evaluation.reason = "unhealthy: " + join_rules(unhealthy_rules);
    return evaluation;
  }

  if (!warning_rules.empty()) {
    evaluation.state = health_state::WARNING;
    evaluation.active_rules = warning_rules;
    evaluation.reason = "warning: " + join_rules(warning_rules);
    return evaluation;
  }

  evaluation.state = health_state::HEALTHY;
  evaluation.reason = "healthy: pipeline metrics within thresholds";
  return evaluation;
}

}  // namespace edge_reliability_health

#endif  // EDGE_RELIABILITY_HEALTH__HEALTH_RULES_HPP_
