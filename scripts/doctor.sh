#!/usr/bin/env bash
# Doctor: status + verify, optional --fix for common repairs.
#
# --fix coverage (idempotent, best-effort):
#   1. Missing Homebrew host tools (Brewfile)
#   2. Docker CLI plugins (cliPluginsExtraDirs)
#   3. Managed DOCKER_HOST block in ~/.zshrc
#   4. Clear sticky DOCKER_CONTEXT / prefer default context
#   5. Stuck / Stopped Lima instance (force stop + start)
#   6. Wait for Lima Docker socket readiness
#   7. Re-apply known-good guest daemon.json (strips bad keys)
#   8. Restart guest rootless Docker if needed
#   9. Nudge buildx default builder after DOCKER_HOST is healthy
#
# Does NOT auto-create a missing Lima instance (run: ducker install).
# shellcheck shell=bash
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/common.sh"

FIX=0
for a in "$@"; do
  case "${a}" in
    --fix | fix) FIX=1 ;;
    -h | --help | help)
      cat <<'EOF'
Usage: ducker doctor [--fix]

  ducker doctor         status + verify
  ducker doctor --fix    apply common repairs, then verify

Repairs (--fix):
  - brew packages if limactl/docker missing
  - host CLI plugins + DOCKER_HOST shell block
  - clear DOCKER_CONTEXT interference
  - force-restart stuck Lima instance
  - wait for Docker socket
  - re-apply guest daemon.json + restart user Docker
  - refresh buildx default when possible
EOF
      exit 0
      ;;
  esac
done

export DOCKER_HOST="${DOCKER_HOST:-unix://${HOME}/.lima/${INSTANCE_NAME}/sock/docker.sock}"
DOCKER_SOCK="${DOCKER_HOST#unix://}"

FIX_APPLIED=0
FIX_SKIPPED=0

fix_ok() {
  printf '  [FIX]  %s\n' "$*"
  FIX_APPLIED=$((FIX_APPLIED + 1))
}

fix_skip() {
  printf '  [SKIP] %s\n' "$*"
  FIX_SKIPPED=$((FIX_SKIPPED + 1))
}

fix_warn() {
  printf '  [WARN] %s\n' "$*" >&2
}

# --- Repair steps -----------------------------------------------------------

fix_host_tools() {
  log "Fix: host tools"
  if command -v limactl >/dev/null 2>&1 && command -v docker >/dev/null 2>&1; then
    if docker compose version >/dev/null 2>&1 && docker buildx version >/dev/null 2>&1; then
      fix_skip "limactl + docker + compose + buildx already present"
      return 0
    fi
  fi
  fix_warn "Missing or incomplete host Docker tooling — running Brewfile install"
  if bash "${ROOT_DIR}/scripts/install-deps.sh"; then
    fix_ok "Homebrew deps / plugins installed"
  else
    fix_warn "install-deps failed — run: ducker deps"
  fi
}

fix_cli_plugins() {
  log "Fix: Docker CLI plugins (cliPluginsExtraDirs)"
  if bash "${ROOT_DIR}/scripts/install-docker-cli-config.sh"; then
    fix_ok "merged cliPluginsExtraDirs into ${DOCKER_CONFIG_JSON}"
  else
    fix_warn "could not update ${DOCKER_CONFIG_JSON}"
  fi
}

fix_shell_env() {
  log "Fix: DOCKER_HOST shell block"
  if bash "${ROOT_DIR}/scripts/install-shell-env.sh"; then
    fix_ok "managed block in ${ZSHRC_FILE}"
  else
    fix_warn "could not update ${ZSHRC_FILE}"
  fi
}

fix_docker_context() {
  log "Fix: Docker context / DOCKER_HOST for this session"
  # Sticky contexts often point at Docker Desktop's /var/run/docker.sock
  unset DOCKER_CONTEXT || true
  export DOCKER_HOST
  if command -v docker >/dev/null 2>&1; then
    # Prefer default context; ignore failures on older clients
    docker context use default >/dev/null 2>&1 || true
    # Remove broken lima-* contexts that confuse buildx listings (optional)
    local ctx
    while IFS= read -r ctx; do
      [[ -n "${ctx}" ]] || continue
      case "${ctx}" in
        lima-"${INSTANCE_NAME}" | lima-docker)
          docker context rm "${ctx}" >/dev/null 2>&1 || true
          fix_ok "removed leftover context ${ctx}"
          ;;
      esac
    done < <(docker context ls -q 2>/dev/null || true)
  fi
  fix_ok "DOCKER_HOST=${DOCKER_HOST} (DOCKER_CONTEXT unset)"
}

fix_lima_instance() {
  log "Fix: Lima instance '${INSTANCE_NAME}'"
  if ! command -v limactl >/dev/null 2>&1; then
    fix_skip "limactl not installed"
    return 0
  fi
  if ! lima_exists; then
    fix_warn "no instance '${INSTANCE_NAME}' — create with: ducker install  (or ducker lima)"
    return 0
  fi
  if lima_running; then
    fix_skip "instance already Running"
    return 0
  fi
  fix_warn "instance not Running — force stop + start (clears stale hostagent)"
  limactl stop -f "${INSTANCE_NAME}" 2>/dev/null || true
  if limactl start --tty=false "${INSTANCE_NAME}"; then
    fix_ok "started instance '${INSTANCE_NAME}'"
  else
    fix_warn "limactl start failed — check: limactl list && tail ~/.lima/${INSTANCE_NAME}/ha.stderr.log"
  fi
}

fix_wait_docker_socket() {
  log "Fix: wait for Docker socket"
  if ! lima_running; then
    fix_skip "VM not Running — no socket wait"
    return 0
  fi
  local n
  for n in $(seq 1 45); do
    if [[ -S "${DOCKER_SOCK}" ]] && DOCKER_HOST="${DOCKER_HOST}" DOCKER_CONTEXT='' docker info >/dev/null 2>&1; then
      fix_ok "Docker socket ready (${DOCKER_SOCK}) after ~$((n * 2))s"
      return 0
    fi
    sleep 2
  done
  fix_warn "socket not ready after ~90s — try: ducker restart && ducker diagnose"
}

fix_guest_daemon() {
  log "Fix: guest rootless daemon.json"
  if ! lima_running; then
    fix_skip "VM not Running — skipped daemon.json"
    return 0
  fi
  # Replacing with our known-good JSON removes bad keys such as:
  # cliPluginsExtraDirs, storage-driver: overlay2, features.buildkit
  if bash "${ROOT_DIR}/scripts/install-daemon-config.sh"; then
    fix_ok "applied config/daemon.json + restarted user Docker"
  else
    fix_warn "daemon apply failed — attempting guest Docker restart only"
    limactl shell "${INSTANCE_NAME}" -- bash -lc \
      'systemctl --user restart docker || dockerd-rootless-setuptool.sh install || true' \
      2>/dev/null || true
  fi
}

fix_guest_docker_active() {
  log "Fix: ensure guest Docker user unit is active"
  if ! lima_running; then
    fix_skip "VM not Running"
    return 0
  fi
  if DOCKER_HOST="${DOCKER_HOST}" DOCKER_CONTEXT='' docker info >/dev/null 2>&1; then
    fix_skip "docker info already OK"
    return 0
  fi
  fix_warn "docker info failed — restarting guest docker"
  limactl shell "${INSTANCE_NAME}" -- bash -lc '
    set -euo pipefail
    systemctl --user start dbus 2>/dev/null || true
    systemctl --user restart docker
    systemctl --user --quiet is-active docker
  ' 2>/dev/null || true
  sleep 3
  if DOCKER_HOST="${DOCKER_HOST}" DOCKER_CONTEXT='' docker info >/dev/null 2>&1; then
    fix_ok "guest Docker responding after restart"
  else
    fix_warn "still unreachable — journalctl --user -u docker inside guest"
  fi
}

fix_buildx_default() {
  log "Fix: buildx default builder"
  if ! command -v docker >/dev/null 2>&1; then
    fix_skip "docker CLI missing"
    return 0
  fi
  if ! DOCKER_HOST="${DOCKER_HOST}" DOCKER_CONTEXT='' docker info >/dev/null 2>&1; then
    fix_skip "daemon unreachable — skip buildx"
    return 0
  fi
  if DOCKER_HOST="${DOCKER_HOST}" DOCKER_CONTEXT='' docker buildx inspect default >/dev/null 2>&1; then
    fix_skip "buildx default already healthy"
    return 0
  fi
  # With DOCKER_HOST set, default builder should track the engine; nudge inspect/ls
  DOCKER_HOST="${DOCKER_HOST}" DOCKER_CONTEXT='' docker buildx ls >/dev/null 2>&1 || true
  if DOCKER_HOST="${DOCKER_HOST}" DOCKER_CONTEXT='' docker buildx inspect default >/dev/null 2>&1; then
    fix_ok "buildx default healthy after refresh"
  else
    fix_warn "buildx default still unhealthy — ensure DOCKER_HOST in new shells (source ~/.zshrc)"
  fi
}

run_fixes() {
  log "Doctor --fix: applying common repairs"
  require_macos_arm
  echo
  fix_host_tools
  echo
  fix_cli_plugins
  echo
  fix_shell_env
  echo
  fix_docker_context
  echo
  fix_lima_instance
  echo
  fix_wait_docker_socket
  echo
  fix_guest_daemon
  echo
  fix_guest_docker_active
  echo
  fix_buildx_default
  echo
  log "Doctor --fix summary: ${FIX_APPLIED} applied, ${FIX_SKIPPED} skipped"
  warn "Open a new terminal (or: source ${ZSHRC_FILE}) so DOCKER_HOST is loaded"
}

# --- Main -------------------------------------------------------------------

log "Doctor — status"
make -C "${ROOT_DIR}" --no-print-directory status || true

echo
if [[ "${FIX}" -eq 1 ]]; then
  run_fixes
  echo
fi

log "Doctor — verify"
if bash "${ROOT_DIR}/scripts/verify.sh"; then
  log "Doctor: healthy"
  exit 0
fi

warn "Doctor: verification failed"
if [[ "${FIX}" -eq 0 ]]; then
  warn "Try: ducker doctor --fix"
else
  warn "Repairs were attempted but verify still fails"
  warn "Next: ducker diagnose"
  warn "Docs: https://nasraldin.github.io/docker-lab/troubleshooting/"
fi
exit 1
