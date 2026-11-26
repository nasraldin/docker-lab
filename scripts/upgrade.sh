#!/usr/bin/env bash
# Preview or apply an upgrade of host Brewfile packages and lab configuration.
# shellcheck shell=bash
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/common.sh"

brewfile_formulae() {
  awk '$1 == "brew" { gsub(/["\047,]/, "", $2); print $2 }' "${ROOT_DIR}/Brewfile"
}

brew_read() (
  export HOMEBREW_NO_AUTO_UPDATE=1 HOMEBREW_NO_ANALYTICS=1 HOMEBREW_NO_BOOTSNAP=1
  unset HOMEBREW_FORCE_API_AUTO_UPDATE
  brew "$@"
)

plan_host() {
  local installed outdated pkg versions update
  log "Host Brewfile formulae (available Homebrew metadata)"
  if ! command -v brew >/dev/null 2>&1; then
    warn "Homebrew unavailable. Install Homebrew before applying the upgrade."
    return
  fi
  if ! installed="$(brew_read list --formula --versions 2>/dev/null)"; then
    warn "Installed Homebrew formulae could not be listed."
    return
  fi
  if ! outdated="$(brew_read outdated --formula --verbose 2>/dev/null)"; then
    warn "Homebrew update availability could not be checked."
  fi

  while IFS= read -r pkg; do
    versions="$(awk -v pkg="${pkg}" '$1 == pkg { $1 = ""; sub(/^ /, ""); print; exit }' <<<"${installed}")"
    update="$(awk -v pkg="${pkg}" '$1 == pkg { print; exit }' <<<"${outdated}")"
    if [[ -z "${versions}" ]]; then
      printf '  %s is missing\n' "${pkg}"
    elif [[ -n "${update}" ]]; then
      printf '  %s\n' "${update}"
    else
      printf '  %s (installed %s)\n' "${pkg}" "${versions}"
    fi
  done < <(brewfile_formulae)
}

plan_guest() {
  local policy versions
  log "Guest Docker packages (cached Debian APT metadata)"
  if [[ "$1" != Running ]]; then
    warn "Guest package information unavailable (Lima status: $1)."
    return
  fi
  if ! policy="$(limactl shell "${INSTANCE_NAME}" -- env LC_ALL=C apt-cache \
    -o Dir::Cache::pkgcache= -o Dir::Cache::srcpkgcache= policy \
    docker-ce docker-ce-cli docker-ce-rootless-extras containerd.io docker-compose-plugin docker-buildx-plugin 2>/dev/null)"; then
    warn "Guest APT metadata could not be read."
    return
  fi
  versions="$(awk '
    /^[^[:space:]].*:$/ { package = $1; sub(/:$/, "", package) }
    $1 == "Installed:" { installed = $2 }
    $1 == "Candidate:" { printf "  %s  installed %s, cached candidate %s\n", package, installed, $2 }
  ' <<<"${policy}")"
  if [[ -n "${versions}" ]]; then
    printf '%s\n' "${versions}"
  else
    warn "No guest Docker packages found in the cached APT metadata."
  fi
}

lab_docker() {
  DOCKER_CONTEXT='' DOCKER_HOST='' docker --host "$(lima_docker_host)" "$@"
}

registry_image_id() {
  command -v jq >/dev/null 2>&1 || return 1
  docker manifest inspect --verbose -- "$1" 2>/dev/null |
    jq -er '
      first(
        (if type == "array" then .[] else . end) |
        select(.Descriptor.platform.os == "linux" and .Descriptor.platform.architecture == "arm64") |
        (.OCIManifest.config.digest // .SchemaV2Manifest.config.digest // empty)
      )
    ' 2>/dev/null
}

plan_ui() {
  local compose provider image local_id registry_id containers="" reachable=0 configured=0
  log "Configured UI images (Linux arm64)"
  if [[ "$1" == Running ]] && containers="$(lab_docker container ls --all --format '{{.Names}}' 2>/dev/null)"; then
    reachable=1
  fi
  for compose in "${ROOT_DIR}"/apps/ui/*/compose.yaml; do
    [[ -f "${compose}" ]] || continue
    provider="$(basename "$(dirname "${compose}")")"
    if [[ ! -f "${compose%/*}/.env" ]] && ! grep -Fxq "ui-${provider}" <<<"${containers}"; then
      continue
    fi
    configured=1
    image="$(awk '$1 == "image:" { gsub(/["\047]/, "", $2); print $2; exit }' "${compose}")"
    printf '  %s (%s)\n' "${provider}" "${image:-unknown image}"
    if [[ -z "${image}" ]]; then
      printf '    Image reference unavailable\n'
      continue
    fi
    local_id=""
    if [[ "${reachable}" == 0 ]]; then
      printf '    Local image unavailable (Docker daemon unreachable)\n'
    elif local_id="$(lab_docker container inspect --format '{{.Image}}' "ui-${provider}" 2>/dev/null)" ||
      local_id="$(lab_docker image inspect --format '{{.Id}}' "${image}" 2>/dev/null)"; then
      printf '    Local image     %s\n' "${local_id}"
    else
      printf '    Local image missing\n'
    fi
    if registry_id="$(registry_image_id "${image}")" && [[ -n "${registry_id}" ]]; then
      printf '    Registry image  %s\n' "${registry_id}"
      if [[ -n "${local_id}" && "${local_id}" == "${registry_id}" ]]; then
        printf '    Image matches the registry\n'
      elif [[ -n "${local_id}" ]]; then
        printf '    Image update available\n'
      fi
    else
      printf '    Registry image unavailable\n'
    fi
  done
  if [[ "${configured}" == 0 ]]; then
    if [[ "${reachable}" == 0 ]]; then
      printf '  No UI .env files found. Docker containers could not be checked.\n'
    else
      printf '  No UI providers configured.\n'
    fi
  fi
}

plan_daemon() {
  local action
  if ! action="$(limactl shell "${INSTANCE_NAME}" -- bash -c '
    set -euo pipefail
    config="${XDG_CONFIG_HOME:-${HOME}/.config}/docker/daemon.json"
    if [[ ! -f "$config" ]]; then
      echo changed
      exit
    fi
    candidate="$(jq -s ".[0] * .[1]" "$config" -)"
    if ! printf "%s\n" "$candidate" | cmp -s - "$config"; then
      echo changed
    elif ! systemctl --user --quiet is-active docker; then
      echo inactive
    else
      echo unchanged
    fi
  ' <"${ROOT_DIR}/config/daemon.json")"; then
    action=unknown
  fi
  case "$action" in
    changed) printf '  Daemon settings differ. Applying them will restart rootless Docker and can interrupt running containers.\n' ;;
    inactive) printf '  Daemon settings match. Applying will start the inactive rootless Docker service.\n' ;;
    unchanged) printf '  Daemon settings match. No Docker restart expected.\n' ;;
    *) printf '  Daemon comparison unavailable. Applying changed settings may restart rootless Docker.\n' ;;
  esac
}

show_plan() {
  local status
  log "Upgrade plan for Lima instance '${INSTANCE_NAME}'"
  status="$(lima_status 2>/dev/null || true)"
  status="${status:-unavailable}"
  plan_host
  plan_guest "${status}"
  plan_ui "${status}"
  log "What ducker upgrade applies"
  printf '  Refresh Homebrew metadata, install or upgrade Brewfile formulae, and re-apply Docker CLI and shell configuration.\n'
  printf '  Guest APT packages and UI images are reported for information only.\n'
  if [[ "${status}" == Running ]]; then
    plan_daemon
    printf '  Run ducker verify to check host tools, Lima, rootless Docker and Buildx. This runs a temporary hello-world container.\n'
  else
    printf '  Lima status is %s. Daemon configuration and verification require a running instance.\n' "${status}"
    printf '  When ready, run ducker start, ducker daemon, then ducker verify.\n'
  fi
}

usage() {
  printf 'Usage: ducker upgrade [--plan]\n  --plan  Preview host, guest and UI update information without applying changes.\n'
}

case "$#:${1-}" in
  1:--plan)
    require_macos_arm
    require_file "${ROOT_DIR}/Brewfile"
    show_plan
    exit 0
    ;;
  1:-h | 1:--help)
    usage
    exit 0
    ;;
  0:) ;;
  *)
    usage >&2
    exit 1
    ;;
esac

require_macos_arm
ensure_brew
require_file "${ROOT_DIR}/Brewfile"

log "Upgrading Homebrew packages from Brewfile"
brew update
brew bundle --file="${ROOT_DIR}/Brewfile"
# Upgrade formulae named in Brewfile when already installed.
while IFS= read -r pkg; do
  brew upgrade "${pkg}" 2>/dev/null || true
done < <(brewfile_formulae)

log "Re-applying host Docker CLI + shell config"
bash "${ROOT_DIR}/scripts/install-docker-cli-config.sh"
bash "${ROOT_DIR}/scripts/install-shell-env.sh"

if lima_running; then
  log "Re-applying guest daemon.json"
  bash "${ROOT_DIR}/scripts/install-daemon-config.sh"
  log "Verifying"
  bash "${ROOT_DIR}/scripts/verify.sh"
else
  warn "Lima instance not Running — skipped daemon re-apply and verify"
  warn "Start with: ducker start && ducker daemon && ducker verify"
fi

log "Upgrade finished (host packages and lab configuration)"
