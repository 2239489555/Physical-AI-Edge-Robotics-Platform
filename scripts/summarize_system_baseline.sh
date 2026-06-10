#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'EOF'
Create a sanitized summary from a collected Jetson preflight directory.

Usage:
  bash scripts/summarize_system_baseline.sh [preflight_dir]
  bash scripts/summarize_system_baseline.sh --help

If preflight_dir is omitted, the newest runtime/artifacts/preflight/* directory is used.

The summary is written to:
  <preflight_dir>/SUMMARY.sanitized.md

The script reads local runtime artifacts only. It does not install packages,
modify system files, or copy raw logs into git-tracked docs.
EOF
}

if [[ "${1:-}" == "--help" || "${1:-}" == "-h" ]]; then
  usage
  exit 0
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
PREFLIGHT_ROOT="${REPO_ROOT}/runtime/artifacts/preflight"

if [[ $# -gt 1 ]]; then
  echo "Expected zero or one preflight directory argument." >&2
  usage >&2
  exit 2
fi

if [[ $# -eq 1 ]]; then
  PREFLIGHT_DIR="$1"
else
  if [[ ! -d "${PREFLIGHT_ROOT}" ]]; then
    echo "No preflight directory found: ${PREFLIGHT_ROOT}" >&2
    exit 1
  fi
  PREFLIGHT_DIR="$(find "${PREFLIGHT_ROOT}" -mindepth 1 -maxdepth 1 -type d | sort | tail -n 1)"
fi

if [[ -z "${PREFLIGHT_DIR}" || ! -d "${PREFLIGHT_DIR}" ]]; then
  echo "Preflight directory does not exist: ${PREFLIGHT_DIR:-<empty>}" >&2
  exit 1
fi

PREFLIGHT_DIR="$(cd "${PREFLIGHT_DIR}" && pwd)"

case "${PREFLIGHT_DIR}" in
  "${REPO_ROOT}"/runtime/artifacts/preflight/*) ;;
  *)
    echo "Refusing to read outside project preflight artifacts: ${PREFLIGHT_DIR}" >&2
    exit 1
    ;;
esac

OUT_FILE="${PREFLIGHT_DIR}/SUMMARY.sanitized.md"

file() {
  local name="$1"
  printf '%s/%s' "${PREFLIGHT_DIR}" "${name}"
}

has_marker() {
  local target="$1"
  [[ -f "${target}" ]] && grep -q '\[collector\] command exited non-zero' "${target}"
}

first_match() {
  local target="$1"
  local pattern="$2"
  if [[ -f "${target}" ]]; then
    grep -E "${pattern}" "${target}" | head -n 1 | sed 's/[[:space:]]\+$//' || true
  fi
}

package_version() {
  local package_name="$1"
  local target
  target="$(file "14_ai_stack_packages.txt")"
  if [[ -f "${target}" ]]; then
    awk -v pkg="${package_name}" '$1 == pkg {print $2; found=1; exit} END {if (!found) exit 1}' "${target}" 2>/dev/null || true
  fi
}

command_status() {
  local target="$1"
  if [[ ! -f "${target}" ]]; then
    echo "missing artifact"
  elif has_marker "${target}"; then
    echo "missing or command failed"
  else
    echo "available"
  fi
}

os_pretty="$(first_match "$(file "01_os_release.txt")" '^PRETTY_NAME=' | sed 's/^PRETTY_NAME=//; s/^"//; s/"$//')"
arch="$(tail -n +3 "$(file "02_architecture.txt")" 2>/dev/null | head -n 1 | tr -d '\r' || true)"
l4t="$(tail -n +3 "$(file "03_l4t_release.txt")" 2>/dev/null | head -n 1 | sed 's/[[:space:]]\+$//' || true)"
l4t_core="$(tail -n +3 "$(file "04_nvidia_l4t_core.txt")" 2>/dev/null | head -n 1 | sed 's/[[:space:]]\+$//' || true)"
cuda="$(first_match "$(file "06_cuda.txt")" 'release [0-9]+[.][0-9]+' | sed -E 's/.*release ([0-9]+[.][0-9]+).*/\1/')"
python_version="$(first_match "$(file "07_python.txt")" '^Python ')"
pip_version="$(first_match "$(file "07_python.txt")" '^pip ')"
cmake_version="$(first_match "$(file "08_build_tools.txt")" '^cmake version ')"
gcc_version="$(first_match "$(file "08_build_tools.txt")" '^gcc .* [0-9]')"
gpp_version="$(first_match "$(file "08_build_tools.txt")" '^g\+\+ .* [0-9]')"
colcon_status="$(command_status "$(file "08_build_tools.txt")")"
docker_status="$(command_status "$(file "12_docker.txt")")"
ros2_status="$(command_status "$(file "17_ros_commands.txt")")"
tegrastats_status="$(command_status "$(file "18_tegrastats_sample.txt")")"

tensorrt_version="$(package_version "libnvinfer10")"
if [[ -z "${tensorrt_version}" ]]; then
  tensorrt_version="$(package_version "tensorrt")"
fi
cudnn_version="$(package_version "cudnn9-cuda-12")"
if [[ -z "${cudnn_version}" ]]; then
  cudnn_version="$(package_version "libcudnn9-cuda-12")"
fi
vpi_version="$(package_version "libnvvpi3")"
nvidia_container_toolkit="$(package_version "nvidia-container-toolkit")"
nvidia_container_runtime="$(package_version "nvidia-container-runtime")"

disk_summary="$(tail -n +3 "$(file "09_disk.txt")" 2>/dev/null | awk '$6 == "/" {print $4 " free on /"; found=1} END {if (!found) exit 1}' 2>/dev/null || true)"
ram_summary="$(tail -n +3 "$(file "10_memory.txt")" 2>/dev/null | awk '$1 == "Mem:" {print $2 " total, " $7 " available"; found=1} END {if (!found) exit 1}' 2>/dev/null || true)"
nvpmodel_summary="$(tail -n +3 "$(file "11_nvpmodel.txt")" 2>/dev/null | grep -E 'NV Power Mode|Power Mode|MODE' | head -n 2 | tr '\n' '; ' | sed 's/[; ]\+$//' || true)"

collector_errors="$(
  for f in "${PREFLIGHT_DIR}"/*.txt; do
    [[ -f "${f}" ]] || continue
    if has_marker "${f}"; then
      basename "${f}"
    fi
  done | paste -sd ', ' -
)"

cat >"${OUT_FILE}" <<EOF
# Sanitized Jetson Baseline Summary

Source artifact directory:

\`\`\`text
${PREFLIGHT_DIR}
\`\`\`

## Short Summary

| Field | Value |
| --- | --- |
| OS | ${os_pretty:-unknown} |
| Architecture | ${arch:-unknown} |
| L4T | ${l4t:-unknown} |
| nvidia-l4t-core | ${l4t_core:-unknown} |
| CUDA | ${cuda:-unknown} |
| TensorRT | ${tensorrt_version:-unknown} |
| cuDNN | ${cudnn_version:-unknown} |
| VPI | ${vpi_version:-unknown} |
| Python | ${python_version:-unknown} |
| pip | ${pip_version:-unknown} |
| CMake | ${cmake_version:-unknown} |
| GCC | ${gcc_version:-unknown} |
| G++ | ${gpp_version:-unknown} |
| colcon | ${colcon_status} |
| Docker | ${docker_status} |
| NVIDIA container toolkit | ${nvidia_container_toolkit:-unknown} |
| NVIDIA container runtime | ${nvidia_container_runtime:-unknown} |
| nvpmodel | ${nvpmodel_summary:-unknown} |
| Disk | ${disk_summary:-unknown} |
| RAM | ${ram_summary:-unknown} |
| ROS 2 | ${ros2_status} |
| tegrastats | ${tegrastats_status} |
| Collector warnings | ${collector_errors:-none} |

## Dependency Decision Gate

Do not install dependencies until this summary is reviewed.

Next likely decision:

- If ROS 2 is missing, plan ROS 2 Humble install and record it in \`docs/system_change_log.md\` before running install commands.
- If colcon is missing, install only the minimal ROS 2 development tooling needed for P0-003 after the change is logged.
- Do not run host package upgrades, Ubuntu 24.04 upgrades, ROS 2 Jazzy installs, global Python package installs, or systemd service changes.

## Redaction Note

This summary intentionally omits raw apt source contents, full environment variables, hostnames, IP addresses, usernames, and raw tegrastats lines.
EOF

echo "Sanitized summary written to: ${OUT_FILE}"
