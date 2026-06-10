#!/usr/bin/env bash
set -euo pipefail

simulation_file="${1:-runtime/artifacts/preflight/ros2_humble_install_simulation.txt}"

if [[ ! -f "$simulation_file" ]]; then
  echo "Apt simulation file not found: $simulation_file" >&2
  echo "Usage: $0 [path-to-apt-simulation-output]" >&2
  exit 2
fi

print_section() {
  local title="$1"
  local heading_pattern="$2"

  echo "## $title"
  if ! awk -v heading_pattern="$heading_pattern" '
    $0 ~ heading_pattern {
      printing = 1
      found = 1
      print
      next
    }
    printing && $0 ~ /^(The following|Suggested packages:|Recommended packages:|Use .* autoremove|[0-9]+ upgraded,|Need to get|After this operation)/ {
      printing = 0
    }
    printing {
      print
    }
    END {
      if (!found) {
        exit 1
      }
    }
  ' "$simulation_file"; then
    echo "not found"
  fi
  echo
}

echo "# Apt Simulation Summary"
echo
echo "Source: $simulation_file"
echo

print_section "Packages Apt Says It Would Remove" "^The following packages will be REMOVED:"
print_section "Packages Apt Says It Would Upgrade" "^The following packages will be upgraded:"
print_section "New Packages Apt Says It Would Install" "^The following NEW packages will be installed:"

echo "## Final Count"
grep -E '^[0-9]+ upgraded, [0-9]+ newly installed, [0-9]+ to remove' "$simulation_file" || echo "not found"
echo

echo "## Simulated Remove Actions"
grep -E '^Remv ' "$simulation_file" || echo "none found"
echo

echo "## Watched Package Actions"
watched_package_pattern='^(Inst|Remv|Conf) (nvidia|cuda|libcuda|libnvinfer|tensorrt|cudnn|vpi|docker|containerd|libnvidia|nvidia-container|nvidia-l4t|linux-image|linux-headers|linux-modules|ubuntu-|systemd|apt|dpkg|libc6|libssl[0-9]*|libssl-dev|openssl|libsqlite3-[0-9]*|libsqlite3-dev)([^[:alnum:]_.+-]|$)'
grep -E "$watched_package_pattern" "$simulation_file" || echo "none found"
echo

echo "## Last 80 Lines"
tail -n 80 "$simulation_file"
