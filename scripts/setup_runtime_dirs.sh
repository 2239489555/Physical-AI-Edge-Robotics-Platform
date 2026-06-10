#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
RUNTIME_DIR="${REPO_ROOT}/runtime"

case "${RUNTIME_DIR}" in
  "${REPO_ROOT}"/*) ;;
  *)
    echo "Refusing to create runtime directory outside repository: ${RUNTIME_DIR}" >&2
    exit 1
    ;;
esac

mkdir -p \
  "${RUNTIME_DIR}/datasets" \
  "${RUNTIME_DIR}/bags" \
  "${RUNTIME_DIR}/logs" \
  "${RUNTIME_DIR}/results" \
  "${RUNTIME_DIR}/artifacts" \
  "${RUNTIME_DIR}/cache" \
  "${RUNTIME_DIR}/tmp"

cat > "${RUNTIME_DIR}/README.local.md" <<'EOF'
# Local Runtime Artifacts

This directory is intentionally ignored by git.

Use it for project-local Jetson runtime outputs:

- datasets/
- bags/
- logs/
- results/
- artifacts/
- cache/
- tmp/

Do not commit this directory.
EOF

echo "Runtime directories ready under: ${RUNTIME_DIR}"
