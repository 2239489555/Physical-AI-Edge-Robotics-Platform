#ifndef EDGE_RELIABILITY_SYSTEM__TEGRASTATS_PARSER_HPP_
#define EDGE_RELIABILITY_SYSTEM__TEGRASTATS_PARSER_HPP_

#include <algorithm>
#include <cctype>
#include <cstddef>
#include <numeric>
#include <optional>
#include <regex>
#include <stdexcept>
#include <string>
#include <vector>

namespace edge_reliability_system
{

struct TegrastatsMetrics
{
  double ram_used_mb{0.0};
  double ram_total_mb{0.0};
  double swap_used_mb{0.0};
  double swap_total_mb{0.0};
  double cpu_percent{0.0};
  double gpu_percent{0.0};
  double temperature_c{0.0};
  double power_w{0.0};
  std::string source{"tegrastats"};
  std::string raw_line{};
};

inline std::string trim(const std::string & text)
{
  const auto begin = std::find_if_not(text.begin(), text.end(), [](unsigned char value) {
      return std::isspace(value) != 0;
    });
  const auto end = std::find_if_not(text.rbegin(), text.rend(), [](unsigned char value) {
      return std::isspace(value) != 0;
    }).base();

  if (begin >= end) {
    return "";
  }

  return std::string(begin, end);
}

inline std::optional<double> parse_double(const std::string & value)
{
  try {
    return std::stod(value);
  } catch (const std::invalid_argument &) {
    return std::nullopt;
  } catch (const std::out_of_range &) {
    return std::nullopt;
  }
}

inline std::optional<TegrastatsMetrics> parse_tegrastats_line(const std::string & raw_line)
{
  const auto line = trim(raw_line);
  if (line.empty()) {
    return std::nullopt;
  }

  std::smatch match;
  static const std::regex ram_regex(R"(RAM\s+([0-9]+(?:\.[0-9]+)?)/([0-9]+(?:\.[0-9]+)?)MB)");
  if (!std::regex_search(line, match, ram_regex)) {
    return std::nullopt;
  }

  auto ram_used = parse_double(match[1].str());
  auto ram_total = parse_double(match[2].str());
  if (!ram_used || !ram_total || *ram_total <= 0.0) {
    return std::nullopt;
  }

  TegrastatsMetrics metrics;
  metrics.ram_used_mb = *ram_used;
  metrics.ram_total_mb = *ram_total;
  metrics.raw_line = line;

  static const std::regex swap_regex(R"(SWAP\s+([0-9]+(?:\.[0-9]+)?)/([0-9]+(?:\.[0-9]+)?)MB)");
  if (std::regex_search(line, match, swap_regex)) {
    auto swap_used = parse_double(match[1].str());
    auto swap_total = parse_double(match[2].str());
    if (swap_used && swap_total) {
      metrics.swap_used_mb = *swap_used;
      metrics.swap_total_mb = *swap_total;
    }
  }

  static const std::regex cpu_block_regex(R"(CPU\s+\[([^\]]+)\])");
  if (std::regex_search(line, match, cpu_block_regex)) {
    const auto cpu_block = match[1].str();
    static const std::regex cpu_percent_regex(R"(([0-9]+(?:\.[0-9]+)?)%@)");
    std::vector<double> percentages;
    for (auto iter = std::sregex_iterator(cpu_block.begin(), cpu_block.end(), cpu_percent_regex);
      iter != std::sregex_iterator(); ++iter)
    {
      auto parsed = parse_double((*iter)[1].str());
      if (parsed) {
        percentages.push_back(*parsed);
      }
    }

    if (!percentages.empty()) {
      metrics.cpu_percent =
        std::accumulate(percentages.begin(), percentages.end(), 0.0) /
        static_cast<double>(percentages.size());
    }
  }

  static const std::regex gr3d_regex(R"(GR3D_FREQ\s+([0-9]+(?:\.[0-9]+)?)%)");
  if (std::regex_search(line, match, gr3d_regex)) {
    auto parsed = parse_double(match[1].str());
    if (parsed) {
      metrics.gpu_percent = *parsed;
    }
  }

  static const std::regex temp_regex(R"(([A-Za-z0-9_]+)@(-?[0-9]+(?:\.[0-9]+)?)C)");
  bool has_temperature = false;
  double max_temperature = 0.0;
  for (auto iter = std::sregex_iterator(line.begin(), line.end(), temp_regex);
    iter != std::sregex_iterator(); ++iter)
  {
    auto parsed = parse_double((*iter)[2].str());
    if (parsed && *parsed >= 0.0) {
      max_temperature = has_temperature ? std::max(max_temperature, *parsed) : *parsed;
      has_temperature = true;
    }
  }
  if (has_temperature) {
    metrics.temperature_c = max_temperature;
  }

  static const std::regex power_regex(
    R"(((?:VDD|VIN)_[A-Za-z0-9_]+)\s+([0-9]+(?:\.[0-9]+)?)mW(?:/[0-9]+(?:\.[0-9]+)?mW)?)");
  double total_power_mw = 0.0;
  for (auto iter = std::sregex_iterator(line.begin(), line.end(), power_regex);
    iter != std::sregex_iterator(); ++iter)
  {
    auto parsed = parse_double((*iter)[2].str());
    if (parsed) {
      total_power_mw += *parsed;
    }
  }
  metrics.power_w = total_power_mw / 1000.0;

  return metrics;
}

}  // namespace edge_reliability_system

#endif  // EDGE_RELIABILITY_SYSTEM__TEGRASTATS_PARSER_HPP_
