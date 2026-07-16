#!/usr/bin/env bash
# Doctor: status + verify, optional --fix for common repairs.
# shellcheck shell=bash
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/common.sh"

FIX=0
for a in "$@"; do
  case "${a}" in
    --fix | fix) FIX=1 ;;
  esac
done

log "Doctor — status"
make -C "${ROOT_DIR}" --no-print-directory status || true

echo
if [[ "${FIX}" -eq 1 ]]; then
  log "Doctor --fix: applying common repairs"
  require_macos_arm
  bash "${ROOT_DIR}/scripts/install-docker-cli-config.sh" || true
  bash "${ROOT_DIR}/scripts/install-shell-env.sh" || true

  if lima_exists && ! lima_running; then
    warn "Instance exists but not Running — forcing stop/start"
    limactl stop -f "${INSTANCE_NAME}" 2>/dev/null || true
    limactl start --tty=false "${INSTANCE_NAME}" || true
  fi

  if lima_running; then
    bash "${ROOT_DIR}/scripts/install-daemon-config.sh" || true
  else
    warn "VM not Running — skipped guest daemon fix (ducker start)"
  fi
fi

echo
log "Doctor — verify"
if bash "${ROOT_DIR}/scripts/verify.sh"; then
  log "Doctor: healthy"
  exit 0
fi

warn "Doctor: verification failed"
warn "Try: ducker doctor --fix"
warn "Or:  ducker diagnose"
exit 1
