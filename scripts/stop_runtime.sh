#!/usr/bin/env bash
set -euo pipefail

# Stops only the processes recorded by scripts/start_runtime.sh.
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
RUNTIME_DIR="$REPO_ROOT/runtime"
RUN_DIR="$RUNTIME_DIR/run/p0_runtime"
LOG_DIR="$RUNTIME_DIR/logs/runtime"
MANIFEST="$RUN_DIR/manifest.tsv"
STATUS_FILE="$RUN_DIR/status.txt"
STOP_LOG="$LOG_DIR/stop_runtime.log"

mkdir -p "$RUN_DIR" "$LOG_DIR"

log() {
  local message="$1"
  printf '%s %s\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)" "$message" | tee -a "$STOP_LOG"
}

signal_process_tree() {
  local signal="$1"
  local pid="$2"
  local child
  local children

  if command -v pgrep >/dev/null 2>&1; then
    children="$(pgrep -P "$pid" 2>/dev/null || true)"
    for child in $children; do
      signal_process_tree "$signal" "$child"
    done
  fi

  kill -s "$signal" "$pid" 2>/dev/null || true
}

wait_for_process_exit() {
  local pid="$1"
  local seconds="$2"
  local deadline=$((SECONDS + seconds))

  while (( SECONDS < deadline )); do
    if ! kill -0 "$pid" 2>/dev/null; then
      return 0
    fi
    sleep 1
  done

  return 1
}

stop_pid() {
  local label="$1"
  local pid="$2"

  if [[ -z "$pid" ]]; then
    log "Skipping $label with empty pid"
    return 0
  fi

  if ! kill -0 "$pid" 2>/dev/null; then
    log "$label pid=$pid is already stopped"
    return 0
  fi

  log "Stopping $label pid=$pid with SIGINT"
  signal_process_tree INT "$pid"
  if wait_for_process_exit "$pid" 8; then
    log "$label pid=$pid stopped after SIGINT"
    return 0
  fi

  log "$label pid=$pid did not stop after SIGINT; sending SIGTERM"
  signal_process_tree TERM "$pid"
  if wait_for_process_exit "$pid" 5; then
    log "$label pid=$pid stopped after SIGTERM"
    return 0
  fi

  log "$label pid=$pid did not stop after SIGTERM; sending SIGKILL"
  signal_process_tree KILL "$pid"
  sleep 1

  if kill -0 "$pid" 2>/dev/null; then
    log "WARNING: $label pid=$pid still appears alive after SIGKILL"
    return 1
  fi

  log "$label pid=$pid stopped after SIGKILL"
}

: > "$STOP_LOG"

if [[ ! -f "$MANIFEST" ]]; then
  log "No runtime manifest found at $MANIFEST; nothing to stop"
  {
    echo "status=stopped"
    echo "stopped_at_utc=$(date -u +%Y-%m-%dT%H:%M:%SZ)"
    echo "reason=no_manifest"
  } > "$STATUS_FILE"
  exit 0
fi

log "Stopping P0 runtime from manifest $MANIFEST"

mapfile -t MANIFEST_LINES < "$MANIFEST"

STOP_FAILED=0
for (( index=${#MANIFEST_LINES[@]} - 1; index >= 0; index-- )); do
  line="${MANIFEST_LINES[$index]}"
  IFS=$'\t' read -r label pid _log_file _command <<< "$line"
  [[ "$label" == "label" || -z "$label" ]] && continue
  if ! stop_pid "$label" "$pid"; then
    STOP_FAILED=1
  fi
done

archive="$RUN_DIR/manifest.stopped.$(date -u +%Y%m%dT%H%M%SZ).tsv"
mv "$MANIFEST" "$archive"

{
  echo "status=stopped"
  echo "stopped_at_utc=$(date -u +%Y-%m-%dT%H:%M:%SZ)"
  echo "manifest_archive=$archive"
  echo "stop_failed=$STOP_FAILED"
} > "$STATUS_FILE"

if [[ "$STOP_FAILED" -ne 0 ]]; then
  log "P0 runtime stop completed with warnings"
  exit 1
fi

log "P0 runtime stopped"
