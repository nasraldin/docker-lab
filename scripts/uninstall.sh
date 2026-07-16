#!/usr/bin/env bash
# Remove Lima Docker stack pieces.
# Modes: soft | instance | host | purge | nuke
#   nuke = literal full cleanup (VM, images, caches, host config, brew packages)
# shellcheck shell=bash
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/common.sh"

MODE="${1:-instance}"

remove_shell_block() {
  require_cmd python3
  [[ -f "${ZSHRC_FILE}" ]] || return 0
  log "Removing managed shell block from ${ZSHRC_FILE}"
  python3 - "${ZSHRC_FILE}" "${MARKER_BEGIN}" "${MARKER_END}" <<'PY'
import pathlib, re, sys
path = pathlib.Path(sys.argv[1])
begin, end = sys.argv[2], sys.argv[3]
text = path.read_text()
pattern = re.compile(
    re.escape(begin) + r".*?" + re.escape(end) + r"\n?",
    flags=re.DOTALL,
)
new = pattern.sub("", text)
if new != text:
    path.write_text(new)
    print(f"cleaned {path}")
else:
    print(f"no managed block found in {path}")
PY
}

remove_cli_plugins_dir() {
  require_cmd python3
  [[ -f "${DOCKER_CONFIG_JSON}" ]] || return 0
  log "Removing Homebrew cliPluginsExtraDirs entry (leaving unrelated Docker config)"
  python3 - "${DOCKER_CONFIG_JSON}" "${CLI_PLUGINS_DIR}" <<'PY'
import json, sys
from pathlib import Path
path = Path(sys.argv[1])
want = sys.argv[2]
cfg = json.loads(path.read_text())
dirs = [d for d in cfg.get("cliPluginsExtraDirs", []) if d != want]
if dirs:
    cfg["cliPluginsExtraDirs"] = dirs
else:
    cfg.pop("cliPluginsExtraDirs", None)
cfg.pop("currentContext", None)
path.write_text(json.dumps(cfg, indent="\t") + "\n")
print(f"updated {path}")
PY
}

stop_instance() {
  if command -v limactl >/dev/null 2>&1 && lima_exists; then
    log "Stopping instance '${INSTANCE_NAME}'"
    limactl stop -f "${INSTANCE_NAME}" || true
  else
    log "Instance '${INSTANCE_NAME}' not found — nothing to stop"
  fi
}

# Wipe containers/images/volumes inside the guest while Docker still responds.
prune_guest_docker() {
  command -v limactl >/dev/null 2>&1 || return 0
  lima_running || return 0
  command -v docker >/dev/null 2>&1 || return 0

  export DOCKER_HOST="unix://${HOME}/.lima/${INSTANCE_NAME}/sock/docker.sock"
  unset DOCKER_CONTEXT || true

  if ! docker info >/dev/null 2>&1; then
    warn "Docker not reachable inside guest — skipping image prune (VM delete will still wipe disk)"
    return 0
  fi

  log "Pruning all Docker containers, images, volumes, networks, and build cache"
  while read -r id; do
    [[ -n "${id}" ]] || continue
    docker rm -f "${id}" >/dev/null 2>&1 || true
  done < <(docker ps -aq 2>/dev/null || true)

  docker system prune -a --volumes -f >/dev/null 2>&1 || true
  docker builder prune -a -f >/dev/null 2>&1 || true
  log "Guest Docker data pruned"
}

delete_instance() {
  prune_guest_docker
  stop_instance
  if command -v limactl >/dev/null 2>&1 && lima_exists; then
    log "Deleting instance '${INSTANCE_NAME}' (VM disk + Docker root wiped)"
    limactl delete -f "${INSTANCE_NAME}"
  else
    log "Instance '${INSTANCE_NAME}' already absent"
  fi

  # Leftover dir if delete was interrupted
  local inst_dir="${HOME}/.lima/${INSTANCE_NAME}"
  if [[ -e "${inst_dir}" ]]; then
    log "Removing leftover instance directory ${inst_dir}"
    rm -rf "${inst_dir}"
  fi
}

prune_lima_caches() {
  log "Pruning Lima download/image caches"
  if command -v limactl >/dev/null 2>&1; then
    limactl prune 2>/dev/null || true
  fi
  rm -rf "${HOME}/Library/Caches/lima"
  # Rejected / temp yaml leftovers from failed starts
  rm -f "${HOME}/lima.REJECTED.yaml" "${PWD}/lima.REJECTED.yaml" 2>/dev/null || true
}

# Full wipe of ~/.lima (instances, _config, _networks, leftovers).
# Used only by nuke/purge — other modes keep sibling Lima VMs intact.
remove_lima_home() {
  local lima_home="${HOME}/.lima"
  if [[ ! -e "${lima_home}" ]]; then
    log "${HOME}/.lima already absent"
    return 0
  fi

  # Stop/delete any remaining named instances before ripping out the tree
  if command -v limactl >/dev/null 2>&1; then
    local name
    while IFS= read -r name; do
      [[ -n "${name}" ]] || continue
      log "Stopping leftover Lima instance '${name}'"
      limactl stop -f "${name}" 2>/dev/null || true
      log "Deleting leftover Lima instance '${name}'"
      limactl delete -f "${name}" 2>/dev/null || true
    done < <(limactl list -q 2>/dev/null || true)
  fi

  log "Removing ${lima_home}"
  rm -rf "${lima_home}"

  if [[ -e "${lima_home}" ]]; then
    die "Failed to remove ${lima_home} — check permissions / open files"
  fi
  log "${HOME}/.lima removed"
}

remove_host_docker_state() {
  log "Cleaning host Docker CLI state tied to this lab"
  # Contexts that pointed at Lima
  if command -v docker >/dev/null 2>&1; then
    docker context rm lima-docker "lima-${INSTANCE_NAME}" 2>/dev/null || true
    docker buildx rm lima-builder 2>/dev/null || true
  fi
  # buildx activity for default/lima is harmless; remove lima-named instances if present
  rm -rf "${HOME}/.docker/buildx/instances/lima-builder" 2>/dev/null || true
  # Copied template from make sync-home-template
  rm -f "${HOME}/lima-docker.yaml"
}

purge_brew() {
  if ! command -v brew >/dev/null 2>&1; then
    warn "brew not found — skipping package uninstall"
    return 0
  fi
  ensure_brew
  log "Uninstalling Homebrew formulae from Brewfile"
  local formulae
  formulae="$(awk '/^brew /{gsub(/"/,"",$2); print $2}' "${ROOT_DIR}/Brewfile")"
  # shellcheck disable=SC2086
  brew uninstall --force ${formulae} 2>/dev/null || true
  brew cleanup -s 2>/dev/null || true
}

is_affirmative() {
  # Accept yes / YES / y / Y (typical terminal prompts)
  case "$(printf '%s' "${1:-}" | tr '[:upper:]' '[:lower:]')" in
    y | yes) return 0 ;;
    *) return 1 ;;
  esac
}

confirm_nuke() {
  printf '\n\033[1mWARNING: destructive full cleanup\033[0m\n'
  printf 'This will remove:\n'
  printf '  - Lima VM "%s" (disk, containers, images, volumes — including UIs)\n' "${INSTANCE_NAME}"
  printf '  - Entire %s/.lima directory (all Lima instances, _config, _networks)\n' "${HOME}"
  printf '  - Lima download caches (~/Library/Caches/lima)\n'
  printf '  - Managed DOCKER_HOST block in ~/.zshrc\n'
  printf '  - Homebrew cliPluginsExtraDirs entry\n'
  printf '  - ~/lima-docker.yaml (if present)\n'
  printf '  - Brew formulae from Brewfile (lima, docker, compose, buildx, yq, jq)\n'
  printf '  - UI local state (apps/ui/.default and provider .env files)\n'
  printf 'Does NOT delete this repo (~/homelab/docker-lab).\n\n'

  if is_affirmative "${CONFIRM:-}"; then
    log "CONFIRM=${CONFIRM} — proceeding without prompt"
    return 0
  fi
  if [[ ! -t 0 ]]; then
    die "Non-interactive shell: re-run with CONFIRM=yes"
  fi
  local ans
  read -r -p 'Type yes to continue: ' ans
  is_affirmative "${ans}" || die "Aborted"
}

nuke_all() {
  log "Nuking docker-lab stack (VM, Docker data, caches, host config, brew packages)"
  delete_instance
  prune_lima_caches
  remove_lima_home
  remove_host_docker_state
  remove_shell_block
  remove_cli_plugins_dir
  # UI provider local state (compose templates kept)
  rm -f "${ROOT_DIR}/apps/ui/.default" \
    "${ROOT_DIR}/apps/ui"/*/.env 2>/dev/null || true
  # Lab backups under XDG share (optional; nuke = full wipe of lab state)
  rm -rf "${HOME}/.local/share/docker-lab" 2>/dev/null || true
  purge_brew
  log "Unset in this shell (new terminals won't load DOCKER_HOST after zshrc cleanup):"
  log "  unset DOCKER_HOST DOCKER_CONTEXT"
}

case "${MODE}" in
  soft)
    stop_instance
    ;;
  instance)
    delete_instance
    ;;
  host)
    delete_instance
    remove_shell_block
    remove_cli_plugins_dir
    ;;
  purge | nuke)
    confirm_nuke
    nuke_all
    warn "Full cleanup done. Reinstall with: cd ~/homelab/docker-lab && make install"
    ;;
  *)
    die "Unknown uninstall mode '${MODE}' (soft|instance|host|purge|nuke)"
    ;;
esac

log "Cleanup mode '${MODE}' complete"
