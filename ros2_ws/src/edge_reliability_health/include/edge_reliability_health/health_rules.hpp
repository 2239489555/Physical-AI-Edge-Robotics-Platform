#ifndef EDGE_RELIABILITY_HEALTH__HEALTH_RULES_HPP_
#define EDGE_RELIABILITY_HEALTH__HEALTH_RULES_HPP_

#include <algorithm>
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
  double max_cpu_percent_warning{85.0};
  double max_cpu_percent_unhealthy{95.0};
  double max_memory_used_percent_warning{80.0};
  double max_memory_used_percent_unhealthy{95.0};
  double max_disk_used_percent_warning{80.0};
  double max_disk_used_percent_unhealthy{95.0};
  double max_gpu_percent_warning{90.0};
  double max_gpu_percent_unhealthy{98.0};
  double max_temperature_c_warning{75.0};
  double max_temperature_c_unhealthy{85.0};
  double max_power_w_warning{45.0};
  double max_power_w_unhealthy{60.0};
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

struct SystemHealthInput
{
  bool available{false};
  double cpu_percent{0.0};
  double memory_used_mb{0.0};
  double memory_total_mb{0.0};
  double disk_used_percent{0.0};
  double gpu_percent{0.0};
  double temperature_c{0.0};
  double power_w{0.0};
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

inline void add_ceiling_rule(
  double value,
  double warning_threshold,
  double unhealthy_threshold,
  const std::string & warning_rule,
  const std::string & unhealthy_rule,
  std::vector<std::string> & warning_rules,
  std::vector<std::string> & unhealthy_rules)
{
  if (value >= unhealthy_threshold) {
    add_rule(unhealthy_rules, unhealthy_rule);
  } else if (value >= warning_threshold) {
    add_rule(warning_rules, warning_rule);
  }
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

inline HealthEvaluation evaluate_system_health(
  const SystemHealthInput & input,
  const HealthThresholds & thresholds)
{
  std::vector<std::string> warning_rules;
  std::vector<std::string> unhealthy_rules;

  if (!input.available) {
    HealthEvaluation evaluation;
    evaluation.state = health_state::HEALTHY;
    evaluation.reason = "healthy: system metrics not yet available";
    return evaluation;
  }

  add_ceiling_rule(
    input.cpu_percent,
    thresholds.max_cpu_percent_warning,
    thresholds.max_cpu_percent_unhealthy,
    "system_cpu_warning",
    "system_cpu_unhealthy",
    warning_rules,
    unhealthy_rules);

  if (input.memory_total_mb > 0.0) {
    const auto memory_used_percent = input.memory_used_mb * 100.0 / input.memory_total_mb;
    add_ceiling_rule(
      memory_used_percent,
      thresholds.max_memory_used_percent_warning,
      thresholds.max_memory_used_percent_unhealthy,
      "system_memory_warning",
      "system_memory_unhealthy",
      warning_rules,
      unhealthy_rules);
  }

  add_ceiling_rule(
    input.disk_used_percent,
    thresholds.max_disk_used_percent_warning,
    thresholds.max_disk_used_percent_unhealthy,
    "system_disk_warning",
    "system_disk_unhealthy",
    warning_rules,
    unhealthy_rules);

  add_ceiling_rule(
    input.gpu_percent,
    thresholds.max_gpu_percent_warning,
    thresholds.max_gpu_percent_unhealthy,
    "system_gpu_warning",
    "system_gpu_unhealthy",
    warning_rules,
    unhealthy_rules);

  add_ceiling_rule(
    input.temperature_c,
    thresholds.max_temperature_c_warning,
    thresholds.max_temperature_c_unhealthy,
    "system_temperature_warning",
    "system_temperature_unhealthy",
    warning_rules,
    unhealthy_rules);

  add_ceiling_rule(
    input.power_w,
    thresholds.max_power_w_warning,
    thresholds.max_power_w_unhealthy,
    "system_power_warning",
    "system_power_unhealthy",
    warning_rules,
    unhealthy_rules);

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
  evaluation.reason = "healthy: system metrics within thresholds";
  return evaluation;
}

inline HealthEvaluation combine_health_evaluations(
  const HealthEvaluation & pipeline_evaluation,
  bool has_pipeline_metrics,
  const HealthEvaluation & system_evaluation,
  bool has_system_metrics)
{
  HealthEvaluation combined;
  combined.state = health_state::HEALTHY;
  combined.reason = "healthy: pipeline and system metrics within thresholds";

  if (has_pipeline_metrics) {
    combined.state = std::max(combined.state, pipeline_evaluation.state);
    combined.active_rules.insert(
      combined.active_rules.end(),
      pipeline_evaluation.active_rules.begin(),
      pipeline_evaluation.active_rules.end());
  }

  if (has_system_metrics) {
    combined.state = std::max(combined.state, system_evaluation.state);
    combined.active_rules.insert(
      combined.active_rules.end(),
      system_evaluation.active_rules.begin(),
      system_evaluation.active_rules.end());
  }

  if (combined.state == health_state::UNHEALTHY) {
    combined.reason = "unhealthy: " + join_rules(combined.active_rules);
  } else if (combined.state == health_state::WARNING) {
    combined.reason = "warning: " + join_rules(combined.active_rules);
  } else if (!has_pipeline_metrics && !has_system_metrics) {
    combined.reason = "healthy: no metrics received yet";
  }

  return combined;
}

}  // namespace edge_reliability_health

#endif  // EDGE_RELIABILITY_HEALTH__HEALTH_RULES_HPP_
