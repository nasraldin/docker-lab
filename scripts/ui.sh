#!/usr/bin/env bash
# Multi-provider Docker UI manager.
# Usage: ui.sh <action> [provider]
#   actions: list|install|up|down|status|open|uninstall|default|help
#   providers: arcane|dockhand
# shellcheck shell=bash
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/common.sh"

UI_ROOT="${ROOT_DIR}/apps/ui"
DEFAULT_FILE="${UI_ROOT}/.default"
KNOWN_PROVIDERS=(arcane dockhand)

ACTION="${1:-help}"
PROVIDER_ARG="${2:-}"

provider_dir()   { printf '%s/%s' "${UI_ROOT}" "$1"; }
compose_file()   { printf '%s/compose.yaml' "$(provider_dir "$1")"; }
env_file()       { printf '%s/.env' "$(provider_dir "$1")"; }

provider_known() {
  local p
  for p in "${KNOWN_PROVIDERS[@]}"; do
    [[ "$p" == "$1" ]] && return 0
  done
  return 1
}

provider_installed() {
  # Compose project present or env file exists (configured)
  [[ -f "$(env_file "$1")" ]] || docker ps -a --format '{{.Names}}' 2>/dev/null | grep -qx "ui-$1"
}

list_installed() {
  local p
  for p in "${KNOWN_PROVIDERS[@]}"; do
    if provider_installed "$p"; then
      printf '%s\n' "$p"
    fi
  done
}

read_default() {
  [[ -f "${DEFAULT_FILE}" ]] || return 1
  local d
  d="$(tr -d '[:space:]' <"${DEFAULT_FILE}")"
  [[ -n "$d" ]] || return 1
  printf '%s' "$d"
}

write_default() {
  provider_known "$1" || die "Unknown provider: $1 (supported: ${KNOWN_PROVIDERS[*]})"
  mkdir -p "${UI_ROOT}"
  printf '%s\n' "$1" >"${DEFAULT_FILE}"
  log "Default UI provider → $1"
}

prompt_default() {
  local installed=("$@")
  local choice
  if [[ "${#installed[@]}" -eq 0 ]]; then
    return 1
  fi
  if [[ "${#installed[@]}" -eq 1 ]]; then
    write_default "${installed[0]}"
    return 0
  fi
  if [[ ! -t 0 ]]; then
    die "Multiple UI providers installed (${installed[*]}). Set default: make ui default <provider>"
  fi
  printf 'Installed UI providers:\n' >&2
  local i
  for i in "${!installed[@]}"; do
    printf '  %d) %s\n' "$((i + 1))" "${installed[$i]}" >&2
  done
  printf 'Choose default [1-%d]: ' "${#installed[@]}" >&2
  read -r choice
  if [[ "${choice}" =~ ^[0-9]+$ ]] && (( choice >= 1 && choice <= ${#installed[@]} )); then
    write_default "${installed[$((choice - 1))]}"
    return 0
  fi
  die "Invalid selection"
}

# Resolve which provider an action should use.
resolve_provider() {
  local action="$1"
  local arg="$2"
  local def installed=()

  if [[ -n "${arg}" ]]; then
    provider_known "${arg}" || die "Unknown provider '${arg}'. Supported: ${KNOWN_PROVIDERS[*]}"
    printf '%s' "${arg}"
    return 0
  fi

  # install without name → default to arcane (first / documented default)
  if [[ "${action}" == "install" ]]; then
    printf 'arcane'
    return 0
  fi

  if def="$(read_default 2>/dev/null)"; then
    printf '%s' "${def}"
    return 0
  fi

  while IFS= read -r line; do
    [[ -n "${line}" ]] && installed+=("${line}")
  done < <(list_installed)

  if [[ "${#installed[@]}" -eq 1 ]]; then
    write_default "${installed[0]}" >/dev/null
    printf '%s' "${installed[0]}"
    return 0
  fi

  if [[ "${#installed[@]}" -gt 1 ]]; then
    prompt_default "${installed[@]}" >/dev/null
    read_default
    return 0
  fi

  die "No UI installed and no provider specified. Try: make ui install arcane"
}

require_stack() {
  require_cmd docker
  lima_running || die "Lima instance '${INSTANCE_NAME}' is not Running — run: make start"
  export DOCKER_HOST="${DOCKER_HOST:-unix://${HOME}/.lima/${INSTANCE_NAME}/sock/docker.sock}"
  unset DOCKER_CONTEXT || true
  docker info >/dev/null 2>&1 || die "Docker daemon not reachable via DOCKER_HOST=${DOCKER_HOST}"
}

compose_for() {
  local p="$1"; shift
  require_file "$(compose_file "$p")" "$(env_file "$p")"
  docker compose --project-name "ui-${p}" --env-file "$(env_file "$p")" -f "$(compose_file "$p")" "$@"
}

detect_guest_docker_sock() {
  local sock
  sock="$(limactl shell "${INSTANCE_NAME}" -- bash -lc 'printf %s "${XDG_RUNTIME_DIR:-/run/user/$(id -u)}/docker.sock"')"
  limactl shell "${INSTANCE_NAME}" -- bash -lc "test -S '${sock}'" \
    || die "Guest Docker socket not found at ${sock} (is rootless Docker running?)"
  printf '%s' "${sock}"
}

detect_guest_ids() {
  limactl shell "${INSTANCE_NAME}" -- bash -lc 'printf "%s %s" "$(id -u)" "$(id -g)"'
}

ensure_env_arcane() {
  local p=arcane
  local ef sock puid pgid enc jwt port app_url
  ef="$(env_file "$p")"
  require_cmd openssl
  mkdir -p "$(provider_dir "$p")"
  sock="$(detect_guest_docker_sock)"
  read -r puid pgid <<<"$(detect_guest_ids)"
  port=3552
  app_url="http://localhost:${port}"
  enc=""; jwt=""
  if [[ -f "${ef}" ]]; then
    # shellcheck disable=SC1090
    set -a; source "${ef}"; set +a
    enc="${ENCRYPTION_KEY:-}"
    jwt="${JWT_SECRET:-}"
    port="${UI_PORT:-${port}}"
    app_url="${APP_URL:-http://localhost:${port}}"
  fi
  [[ -n "${enc}" ]] || enc="$(openssl rand -hex 32)"
  [[ -n "${jwt}" ]] || jwt="$(openssl rand -hex 32)"
  cat >"${ef}" <<EOF
# Managed by docker-lab — do not commit
UI_PORT=${port}
APP_URL=${app_url}
PUID=${puid}
PGID=${pgid}
DOCKER_SOCK=${sock}
ENCRYPTION_KEY=${enc}
JWT_SECRET=${jwt}
TZ=UTC
EOF
  chmod 600 "${ef}"
}

ensure_env_dockhand() {
  local p=dockhand
  local ef sock port app_url
  ef="$(env_file "$p")"
  mkdir -p "$(provider_dir "$p")"
  sock="$(detect_guest_docker_sock)"
  port=9090
  app_url="http://localhost:${port}"
  if [[ -f "${ef}" ]]; then
    # shellcheck disable=SC1090
    set -a; source "${ef}"; set +a
    port="${UI_PORT:-${port}}"
    app_url="${APP_URL:-http://localhost:${port}}"
  fi
  cat >"${ef}" <<EOF
# Managed by docker-lab — do not commit
UI_PORT=${port}
APP_URL=${app_url}
DOCKER_SOCK=${sock}
TZ=UTC
EOF
  chmod 600 "${ef}"
}

ensure_env() {
  case "$1" in
    arcane)   ensure_env_arcane ;;
    dockhand) ensure_env_dockhand ;;
    *) die "No env generator for provider: $1" ;;
  esac
  log "Wrote $(env_file "$1")"
}

maybe_set_default_after_install() {
  local p="$1"
  local installed=() def
  while IFS= read -r line; do
    [[ -n "${line}" ]] && installed+=("${line}")
  done < <(list_installed)

  if ! def="$(read_default 2>/dev/null)"; then
    # First UI install becomes default
    write_default "$p"
    return 0
  fi

  # Another provider already default; if multiple installed, offer to switch
  if [[ "${#installed[@]}" -gt 1 && -t 0 ]]; then
    printf 'UI providers installed: %s\n' "${installed[*]}" >&2
    printf 'Current default: %s\n' "${def}" >&2
    printf 'Set default to "%s"? [y/N] ' "$p" >&2
    local ans
    read -r ans
    if [[ "${ans}" =~ ^[Yy]$ ]]; then
      write_default "$p"
    fi
  fi
}

cmd_help() {
  cat <<'EOF'
Docker UI manager (optional — not part of `make install`)

Usage:
  make ui list
  make ui install [arcane|dockhand]   # default provider if omitted: arcane
  make ui up|down|status|open|uninstall [provider]
  make ui default <provider>          # set default for bare commands
  make ui help

Examples:
  make ui install                 # installs arcane, sets as default
  make ui install dockhand        # install second UI; may ask for default
  make ui open                    # opens default provider
  make ui open dockhand
  make ui default dockhand
  make ui uninstall arcane
EOF
}

cmd_list() {
  local p def status mark
  def="$(read_default 2>/dev/null || true)"
  printf '%-12s %-10s %-8s %s\n' "PROVIDER" "STATUS" "DEFAULT" "URL"
  for p in "${KNOWN_PROVIDERS[@]}"; do
    if provider_installed "$p"; then
      if docker ps --format '{{.Names}}' 2>/dev/null | grep -qx "ui-${p}"; then
        status="running"
      else
        status="stopped"
      fi
    else
      status="-"
    fi
    mark=""
    [[ "$p" == "${def}" ]] && mark="*"
    case "$p" in
      arcane)   url="http://localhost:3552" ;;
      dockhand) url="http://localhost:9090" ;;
      *)        url="-" ;;
    esac
    printf '%-12s %-10s %-8s %s\n' "$p" "$status" "${mark:--}" "$url"
  done
}

cmd_install() {
  local p
  p="$(resolve_provider install "${PROVIDER_ARG}")"
  require_stack
  require_file "$(compose_file "$p")"
  ensure_env "$p"
  # migrate old single-container name
  docker rm -f ui arcane >/dev/null 2>&1 || true
  log "Installing UI provider: ${p}"
  compose_for "$p" pull
  compose_for "$p" up -d --remove-orphans
  maybe_set_default_after_install "$p"
  # shellcheck disable=SC1090
  set -a; source "$(env_file "$p")"; set +a
  log "UI (${p}) → ${APP_URL}"
  case "$p" in
    arcane)
      log "Login: arcane / arcane-admin (change on first sign-in)"
      ;;
    dockhand)
      log "Complete the first-run admin wizard in the browser"
      ;;
  esac
}

cmd_up() {
  local p
  p="$(resolve_provider up "${PROVIDER_ARG}")"
  require_stack
  [[ -f "$(env_file "$p")" ]] || ensure_env "$p"
  compose_for "$p" up -d --remove-orphans
  log "UI (${p}) started"
}

cmd_down() {
  local p
  p="$(resolve_provider down "${PROVIDER_ARG}")"
  require_stack
  [[ -f "$(env_file "$p")" ]] || die "Provider '${p}' not installed"
  compose_for "$p" down
  log "UI (${p}) stopped (data volume kept)"
}

cmd_status() {
  local p
  if [[ -n "${PROVIDER_ARG}" ]]; then
    p="$(resolve_provider status "${PROVIDER_ARG}")"
    require_stack
    compose_for "$p" ps
  else
    require_stack
    cmd_list
    echo
    docker ps --filter name=ui- --format 'table {{.Names}}\t{{.Status}}\t{{.Ports}}'
  fi
}

cmd_open() {
  local p url
  p="$(resolve_provider open "${PROVIDER_ARG}")"
  url="http://localhost:3552"
  if [[ -f "$(env_file "$p")" ]]; then
    # shellcheck disable=SC1090
    set -a; source "$(env_file "$p")"; set +a
    url="${APP_URL}"
  else
    case "$p" in
      dockhand) url="http://localhost:9090" ;;
    esac
  fi
  log "Opening ${p} → ${url}"
  if command -v open >/dev/null 2>&1; then
    open "${url}"
  else
    printf '%s\n' "${url}"
  fi
}

cmd_uninstall() {
  local p def
  p="$(resolve_provider uninstall "${PROVIDER_ARG}")"
  require_stack
  if [[ -f "$(env_file "$p")" ]]; then
    log "Removing UI provider: ${p}"
    compose_for "$p" down -v --remove-orphans
  else
    docker rm -f "ui-${p}" >/dev/null 2>&1 || true
    docker volume rm "ui-${p}_ui-data" >/dev/null 2>&1 || true
  fi
  rm -f "$(env_file "$p")"

  if def="$(read_default 2>/dev/null)" && [[ "${def}" == "$p" ]]; then
    rm -f "${DEFAULT_FILE}"
    local remaining=()
    while IFS= read -r line; do
      [[ -n "${line}" ]] && remaining+=("${line}")
    done < <(list_installed)
    if [[ "${#remaining[@]}" -gt 0 ]]; then
      prompt_default "${remaining[@]}"
    else
      log "No UI providers left — default cleared"
    fi
  fi
  log "UI (${p}) removed"
}

cmd_default() {
  local p="${PROVIDER_ARG}"
  [[ -n "${p}" ]] || die "Usage: make ui default <arcane|dockhand>"
  provider_known "${p}" || die "Unknown provider: ${p}"
  provider_installed "${p}" || warn "Provider '${p}' is not installed yet (default still set)"
  write_default "${p}"
}

case "${ACTION}" in
  help|-h|--help) cmd_help ;;
  list|ls)        cmd_list ;;
  install)        cmd_install ;;
  up|start)       cmd_up ;;
  down|stop)      cmd_down ;;
  status|ps)      cmd_status ;;
  open)           cmd_open ;;
  uninstall|rm)   cmd_uninstall ;;
  default|use)    cmd_default ;;
  *)
    cmd_help
    die "Unknown action: ${ACTION}"
    ;;
esac
