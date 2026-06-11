#include "edge_reliability_system/tegrastats_parser.hpp"

#include <gtest/gtest.h>

namespace
{

using edge_reliability_system::parse_tegrastats_line;

const char kOrinSample[] =
  "RAM 2818/62832MB (lfb 966x4MB) SWAP 0/31416MB (cached 0MB) "
  "CPU [1%@729,0%@729,2%@729,3%@729,0%@729,1%@729,0%@729,0%@729,4%@729,0%@729,1%@729,0%@729] "
  "EMC_FREQ 0%@2133 GR3D_FREQ 7%@306 VIC_FREQ 115 APE 150 "
  "CV0@-256C CPU@37.5C SOC2@35.5C SOC0@35.5C Tboard@31C GPU@36.0C tj@38.0C "
  "VDD_GPU_SOC 390mW/390mW VDD_CPU_CV 720mW/720mW VIN_SYS_5V0 4250mW/4250mW";

const char kLegacySample[] =
  "RAM 4096/16384MB (lfb 1024x4MB) CPU [10%@1190,20%@1190,off,30%@1190,40%@1190] "
  "GR3D_FREQ 55%@921 GPU@51C CPU@50.5C PMIC@45C VDD_IN 8500mW/9000mW";

TEST(TegrastatsParser, ParsesRepresentativeOrinLine)
{
  const auto parsed = parse_tegrastats_line(kOrinSample);

  ASSERT_TRUE(parsed.has_value());
  EXPECT_DOUBLE_EQ(parsed->ram_used_mb, 2818.0);
  EXPECT_DOUBLE_EQ(parsed->ram_total_mb, 62832.0);
  EXPECT_DOUBLE_EQ(parsed->swap_used_mb, 0.0);
  EXPECT_DOUBLE_EQ(parsed->swap_total_mb, 31416.0);
  EXPECT_NEAR(parsed->cpu_percent, 1.0, 0.001);
  EXPECT_DOUBLE_EQ(parsed->gpu_percent, 7.0);
  EXPECT_DOUBLE_EQ(parsed->temperature_c, 38.0);
  EXPECT_NEAR(parsed->power_w, 5.36, 0.001);
}

TEST(TegrastatsParser, HandlesLegacyLineWithOffCpuCore)
{
  const auto parsed = parse_tegrastats_line(kLegacySample);

  ASSERT_TRUE(parsed.has_value());
  EXPECT_DOUBLE_EQ(parsed->ram_used_mb, 4096.0);
  EXPECT_DOUBLE_EQ(parsed->ram_total_mb, 16384.0);
  EXPECT_NEAR(parsed->cpu_percent, 25.0, 0.001);
  EXPECT_DOUBLE_EQ(parsed->gpu_percent, 55.0);
  EXPECT_DOUBLE_EQ(parsed->temperature_c, 51.0);
  EXPECT_NEAR(parsed->power_w, 8.5, 0.001);
}

TEST(TegrastatsParser, RejectsNonTegrastatsLine)
{
  const auto parsed = parse_tegrastats_line("not available");

  EXPECT_FALSE(parsed.has_value());
}

}  // namespace
