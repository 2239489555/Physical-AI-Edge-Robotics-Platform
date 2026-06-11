#include "edge_reliability_processor/pipeline_metrics_accumulator.hpp"

#include <gtest/gtest.h>

namespace edge_reliability_processor
{
namespace
{

TEST(PipelineMetricsAccumulator, ComputesRateLatencyAndSequenceGaps)
{
  PipelineMetricsAccumulator accumulator;
  accumulator.configure(100.0, 5.0, 10);

  accumulator.observe(10, 0, 10000000);
  accumulator.observe(11, 10000000, 20000000);
  accumulator.observe(13, 20000000, 30000000);

  const auto snapshot = accumulator.snapshot(30000000);

  EXPECT_EQ(snapshot.received_count, 3U);
  EXPECT_EQ(snapshot.dropped_count, 1U);
  EXPECT_EQ(snapshot.expected_count, 4U);
  EXPECT_EQ(snapshot.out_of_order_count, 0U);
  EXPECT_NEAR(snapshot.receive_rate_hz, 100.0, 0.001);
  EXPECT_NEAR(snapshot.average_latency_ms, 10.0, 0.001);
  EXPECT_NEAR(snapshot.p95_latency_ms, 10.0, 0.001);
  EXPECT_NEAR(snapshot.p99_latency_ms, 10.0, 0.001);
  EXPECT_NEAR(snapshot.drop_rate, 0.25, 0.001);
}

TEST(PipelineMetricsAccumulator, CountsOutOfOrderSamples)
{
  PipelineMetricsAccumulator accumulator;
  accumulator.configure(100.0, 5.0, 10);

  accumulator.observe(3, 0, 1000000);
  accumulator.observe(2, 1000000, 2000000);
  accumulator.observe(3, 2000000, 3000000);
  accumulator.observe(4, 3000000, 4000000);

  const auto snapshot = accumulator.snapshot(4000000);

  EXPECT_EQ(snapshot.received_count, 4U);
  EXPECT_EQ(snapshot.dropped_count, 0U);
  EXPECT_EQ(snapshot.out_of_order_count, 2U);
  EXPECT_EQ(snapshot.expected_count, 4U);
}

}  // namespace
}  // namespace edge_reliability_processor
