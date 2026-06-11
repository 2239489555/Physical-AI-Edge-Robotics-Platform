#include "edge_reliability_health/health_rules.hpp"

#include <gtest/gtest.h>

#include <algorithm>
#include <string>
#include <vector>

namespace
{

using edge_reliability_health::HealthThresholds;
using edge_reliability_health::PipelineHealthInput;
using edge_reliability_health::SystemHealthInput;
using edge_reliability_health::combine_health_evaluations;
using edge_reliability_health::evaluate_pipeline_health;
using edge_reliability_health::evaluate_system_health;

bool has_rule(const std::vector<std::string> & rules, const std::string & rule)
{
  return std::find(rules.begin(), rules.end(), rule) != rules.end();
}

PipelineHealthInput healthy_input()
{
  PipelineHealthInput input;
  input.received_count = 1000;
  input.expected_count = 1000;
  input.dropped_count = 0;
  input.out_of_order_count = 0;
  input.receive_rate_hz = 99.9;
  input.p95_latency_ms = 0.7;
  input.p99_latency_ms = 1.0;
  input.drop_rate = 0.0;
  return input;
}

TEST(HealthRules, KeepsNormalPipelineHealthy)
{
  const auto evaluation = evaluate_pipeline_health(healthy_input(), HealthThresholds{});

  EXPECT_EQ(evaluation.state, edge_reliability_health::health_state::HEALTHY);
  EXPECT_EQ(evaluation.reason, "healthy: pipeline metrics within thresholds");
  EXPECT_TRUE(evaluation.active_rules.empty());
}

TEST(HealthRules, MarksDropFaultUnhealthy)
{
  auto input = healthy_input();
  input.received_count = 1212;
  input.expected_count = 1500;
  input.dropped_count = 288;
  input.receive_rate_hz = 80.8;
  input.drop_rate = 0.192;

  const auto evaluation = evaluate_pipeline_health(input, HealthThresholds{});

  EXPECT_EQ(evaluation.state, edge_reliability_health::health_state::UNHEALTHY);
  EXPECT_TRUE(has_rule(evaluation.active_rules, "drop_rate_unhealthy"));
  EXPECT_NE(evaluation.reason.find("drop_rate_unhealthy"), std::string::npos);
}

TEST(HealthRules, MarksSubscriberDelayWarning)
{
  auto input = healthy_input();
  input.p95_latency_ms = 8.4;
  input.p99_latency_ms = 8.7;

  const auto evaluation = evaluate_pipeline_health(input, HealthThresholds{});

  EXPECT_EQ(evaluation.state, edge_reliability_health::health_state::WARNING);
  EXPECT_TRUE(has_rule(evaluation.active_rules, "p95_latency_warning"));
}

TEST(HealthRules, MarksSevereLatencyUnhealthy)
{
  auto input = healthy_input();
  input.p95_latency_ms = 22.0;
  input.p99_latency_ms = 55.0;

  const auto evaluation = evaluate_pipeline_health(input, HealthThresholds{});

  EXPECT_EQ(evaluation.state, edge_reliability_health::health_state::UNHEALTHY);
  EXPECT_TRUE(has_rule(evaluation.active_rules, "p95_latency_unhealthy"));
  EXPECT_TRUE(has_rule(evaluation.active_rules, "p99_latency_unhealthy"));
}

TEST(HealthRules, MarksLowReceiveRateWarning)
{
  auto input = healthy_input();
  input.receive_rate_hz = 90.0;

  const auto evaluation = evaluate_pipeline_health(input, HealthThresholds{});

  EXPECT_EQ(evaluation.state, edge_reliability_health::health_state::WARNING);
  EXPECT_TRUE(has_rule(evaluation.active_rules, "receive_rate_warning"));
}

TEST(HealthRules, MarksSystemTemperatureUnhealthy)
{
  SystemHealthInput input;
  input.available = true;
  input.cpu_percent = 12.0;
  input.memory_used_mb = 4096.0;
  input.memory_total_mb = 65536.0;
  input.disk_used_percent = 55.0;
  input.gpu_percent = 18.0;
  input.temperature_c = 89.0;
  input.power_w = 9.0;

  const auto evaluation = evaluate_system_health(input, HealthThresholds{});

  EXPECT_EQ(evaluation.state, edge_reliability_health::health_state::UNHEALTHY);
  EXPECT_TRUE(has_rule(evaluation.active_rules, "system_temperature_unhealthy"));
  EXPECT_NE(evaluation.reason.find("system_temperature_unhealthy"), std::string::npos);
}

TEST(HealthRules, MarksSystemMemoryAndDiskWarning)
{
  SystemHealthInput input;
  input.available = true;
  input.cpu_percent = 12.0;
  input.memory_used_mb = 54.0;
  input.memory_total_mb = 64.0;
  input.disk_used_percent = 82.0;
  input.gpu_percent = 18.0;
  input.temperature_c = 42.0;
  input.power_w = 9.0;

  const auto evaluation = evaluate_system_health(input, HealthThresholds{});

  EXPECT_EQ(evaluation.state, edge_reliability_health::health_state::WARNING);
  EXPECT_TRUE(has_rule(evaluation.active_rules, "system_memory_warning"));
  EXPECT_TRUE(has_rule(evaluation.active_rules, "system_disk_warning"));
}

TEST(HealthRules, CombinesPipelineAndSystemRules)
{
  const auto pipeline = evaluate_pipeline_health(healthy_input(), HealthThresholds{});

  SystemHealthInput system_input;
  system_input.available = true;
  system_input.memory_used_mb = 100.0;
  system_input.memory_total_mb = 100.0;
  const auto system = evaluate_system_health(system_input, HealthThresholds{});

  const auto combined = combine_health_evaluations(pipeline, true, system, true);

  EXPECT_EQ(combined.state, edge_reliability_health::health_state::UNHEALTHY);
  EXPECT_TRUE(has_rule(combined.active_rules, "system_memory_unhealthy"));
  EXPECT_NE(combined.reason.find("system_memory_unhealthy"), std::string::npos);
}

}  // namespace
