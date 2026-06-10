#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'EOF'
Collect a read-only Jetson system baseline.

Usage:
  bash scripts/collect_system_baseline.sh [--dry-run]
  bash scripts/collect_system_baseline.sh --help

The script writes raw command output under:
  runtime/artifacts/preflight/<timestamp>/

It does not install packages, change apt sources, modify shell rc files, or write outside the repository workspace.
EOF
}

DRY_RUN=0
if [[ "${1:-}" == "--help" || "${1:-}" == "-h" ]]; then
  usage
  exit 0
elif [[ "${1:-}" == "--dry-run" ]]; then
  DRY_RUN=1
elif [[ $# -gt 0 ]]; then
  echo "Unknown argument: $1" >&2
  usage >&2
  exit 2
fi

need_command() {
  local name="$1"
  if ! command -v "${name}" >/dev/null 2>&1; then
    echo "Required command is missing: ${name}" >&2
    exit 1
  fi
}

need_command date
need_command mkdir
need_command pwd
need_command sh

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
TIMESTAMP="$(date -u +%Y%m%dT%H%M%SZ)"
OUT_DIR="${REPO_ROOT}/runtime/artifacts/preflight/${TIMESTAMP}"

case "${OUT_DIR}" in
  "${REPO_ROOT}"/*) ;;
  *)
    echo "Refusing to write outside repository: ${OUT_DIR}" >&2
    exit 1
    ;;
esac

record_shell() {
  local name="$1"
  local command_text="$2"
  local output_file="${OUT_DIR}/${name}.txt"

  if [[ "${DRY_RUN}" -eq 1 ]]; then
    echo "[dry-run] ${name}: ${command_text}"
    return 0
  fi

  {
    echo "\$ ${command_text}"
    echo
    sh -c "${command_text}"
  } >"${output_file}" 2>&1 || {
    {
      echo
      echo "[collector] command exited non-zero; keep this output for review."
    } >>"${output_file}"
  }
}

if [[ "${DRY_RUN}" -eq 1 ]]; then
  echo "[dry-run] output directory: ${OUT_DIR}"
else
  mkdir -p "${OUT_DIR}"
fi

record_shell "00_uname" "uname -a"
record_shell "01_os_release" "cat /etc/os-release"
record_shell "02_architecture" "dpkg --print-architecture 2>/dev/null || uname -m"
record_shell "03_l4t_release" "cat /etc/nv_tegra_release"
record_shell "04_nvidia_l4t_core" "dpkg-query --show nvidia-l4t-core"
record_shell "05_jetpack_policy" "apt-cache policy nvidia-jetpack"
record_shell "06_cuda" "nvcc --version"
record_shell "07_python" "python3 --version && python3 -m pip --version"
record_shell "08_build_tools" "cmake --version && gcc --version && g++ --version && colcon --version"
record_shell "09_disk" "df -h"
record_shell "10_memory" "free -h"
record_shell "11_nvpmodel" "nvpmodel -q"
record_shell "12_docker" "docker --version && docker info"
record_shell "13_nvidia_container_runtime" "dpkg-query --show nvidia-container-toolkit nvidia-container-runtime libnvidia-container-tools libnvidia-container1"
record_shell "14_ai_stack_packages" "dpkg-query -W -f='\${binary:Package}\t\${Version}\n' 'nvidia-*' 'cuda-*' 'libnvinfer*' 'tensorrt*' 'cudnn*' 'vpi*' 'ros-*' 'docker*' 'containerd*' 2>/dev/null | sort"
record_shell "15_apt_sources" "find /etc/apt -maxdepth 3 -type f \\( -name 'sources.list' -o -name '*.list' -o -name '*.sources' \\) -print -exec sed -n '1,200p' {} \\;"
record_shell "16_relevant_environment" "env | grep -E '^(ROS|AMENT|COLCON|CUDA|LD_LIBRARY_PATH|PATH|PYTHONPATH|CMAKE_PREFIX_PATH|NVIDIA|JETSON|VPI|TENSORRT)=' | sort"
record_shell "17_ros_commands" "command -v ros2 && ros2 --help | head -n 40"
record_shell "18_tegrastats_sample" "if command -v timeout >/dev/null 2>&1 && command -v tegrastats >/dev/null 2>&1; then timeout 6s tegrastats --interval 1000; else echo 'timeout or tegrastats not available'; fi"

if [[ "${DRY_RUN}" -eq 0 ]]; then
  cat >"${OUT_DIR}/README.md" <<EOF
# Preflight Baseline Artifacts

Collected at: ${TIMESTAMP}

These raw outputs are local-only and ignored by git. Review and summarize sanitized results in:

- docs/system_baseline.md
- docs/system_change_log.md

Do not commit this directory.
EOF
  echo "System baseline artifacts written to: ${OUT_DIR}"
fi
