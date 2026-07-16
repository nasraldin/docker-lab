#!/usr/bin/env bash
# Backup / restore lab configuration (optional Lima VM archive).
# shellcheck shell=bash
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/common.sh"

BACKUP_ROOT="${BACKUP_ROOT:-${HOME}/.local/share/docker-lab/backups}"
INCLUDE_VM=0

usage() {
  cat <<'EOF'
Usage:
  ducker backup [--vm]
  ducker backup list
  ducker restore <backup-id> [--vm]

Stores snapshots under ~/.local/share/docker-lab/backups/<id>/
EOF
}

stamp_id() {
  date +%Y%m%d-%H%M%S
}

list_backups() {
  mkdir -p "${BACKUP_ROOT}"
  if [[ -z "$(ls -A "${BACKUP_ROOT}" 2>/dev/null || true)" ]]; then
    log "No backups yet (ducker backup)"
    return 0
  fi
  printf '%-20s %s\n' "ID" "CONTENTS"
  local d
  for d in "${BACKUP_ROOT}"/*; do
    [[ -d "${d}" ]] || continue
    local bits="config"
    [[ -f "${d}/lima-docker.tar.gz" ]] && bits="${bits}+vm"
    printf '%-20s %s\n' "$(basename "${d}")" "${bits}"
  done
}

do_backup() {
  local id dir
  id="$(stamp_id)"
  dir="${BACKUP_ROOT}/${id}"
  mkdir -p "${dir}/config" "${dir}/host"

  log "Backing up lab config → ${dir}"
  cp -f "${LIMA_TEMPLATE}" "${dir}/lima-docker.yaml"
  cp -f "${ROOT_DIR}/config/daemon.json" "${dir}/config/daemon.json"
  cp -f "${ROOT_DIR}/config.env" "${dir}/config.env" 2>/dev/null || true
  if [[ -f "${ROOT_DIR}/config/profiles/.active" ]]; then
    cp -f "${ROOT_DIR}/config/profiles/.active" "${dir}/profile.active"
  fi
  if [[ -f "${DOCKER_CONFIG_JSON}" ]]; then
    cp -f "${DOCKER_CONFIG_JSON}" "${dir}/host/docker-config.json"
  fi
  if [[ -f "${ZSHRC_FILE}" ]] && grep -qF "${MARKER_BEGIN}" "${ZSHRC_FILE}"; then
    awk -v b="${MARKER_BEGIN}" -v e="${MARKER_END}" '
      $0 == b {p=1}
      p {print}
      $0 == e {p=0}
    ' "${ZSHRC_FILE}" >"${dir}/host/zshrc.snippet"
  fi

  if [[ "${INCLUDE_VM}" -eq 1 ]]; then
    if ! lima_exists; then
      warn "No Lima instance '${INSTANCE_NAME}' — skipping --vm archive"
    else
      if lima_running; then
        log "Stopping instance before VM archive"
        limactl stop "${INSTANCE_NAME}"
      fi
      log "Archiving ~/.lima/${INSTANCE_NAME} (this can be large)"
      tar -C "${HOME}/.lima" -czf "${dir}/lima-docker.tar.gz" "${INSTANCE_NAME}"
    fi
  fi

  printf '%s\n' "${id}" >"${dir}/BACKUP_ID"
  log "Backup complete: ${id}"
  log "Restore with: ducker restore ${id}"
}

do_restore() {
  local id="$1"
  local dir="${BACKUP_ROOT}/${id}"
  [[ -d "${dir}" ]] || die "Backup not found: ${id} (ducker backup list)"

  log "Restoring config from ${dir}"
  require_file "${dir}/lima-docker.yaml" "${dir}/config/daemon.json"
  cp -f "${dir}/lima-docker.yaml" "${LIMA_TEMPLATE}"
  cp -f "${dir}/config/daemon.json" "${ROOT_DIR}/config/daemon.json"
  if [[ -f "${dir}/profile.active" ]]; then
    mkdir -p "${ROOT_DIR}/config/profiles"
    cp -f "${dir}/profile.active" "${ROOT_DIR}/config/profiles/.active"
  fi
  if [[ -f "${dir}/host/docker-config.json" ]]; then
    mkdir -p "$(dirname "${DOCKER_CONFIG_JSON}")"
    cp -f "${dir}/host/docker-config.json" "${DOCKER_CONFIG_JSON}"
  fi
  bash "${ROOT_DIR}/scripts/install-shell-env.sh"

  if [[ "${INCLUDE_VM}" -eq 1 ]]; then
    [[ -f "${dir}/lima-docker.tar.gz" ]] || die "Backup ${id} has no VM archive (re-run backup with --vm)"
    if lima_exists; then
      log "Deleting existing instance '${INSTANCE_NAME}'"
      limactl delete -f "${INSTANCE_NAME}" || true
    fi
    log "Restoring Lima instance archive"
    mkdir -p "${HOME}/.lima"
    tar -C "${HOME}/.lima" -xzf "${dir}/lima-docker.tar.gz"
    log "Start with: ducker start && ducker verify"
  else
    log "Config restored. Re-apply guest daemon if VM is running: ducker daemon"
  fi
}

ARGS=()
for a in "$@"; do
  case "${a}" in
    --vm) INCLUDE_VM=1 ;;
    -h | --help | help)
      usage
      exit 0
      ;;
    *) ARGS+=("${a}") ;;
  esac
done

MODE="${BACKUP_MODE:-}"
if [[ -z "${MODE}" ]]; then
  case "${ARGS[0]:-}" in
    restore)
      MODE=restore
      ARGS=("${ARGS[@]:1}")
      ;;
    list | ls)
      MODE=list
      ARGS=("${ARGS[@]:1}")
      ;;
    "" | backup)
      MODE=backup
      [[ "${ARGS[0]:-}" == "backup" ]] && ARGS=("${ARGS[@]:1}")
      ;;
    *) MODE=backup ;;
  esac
fi

case "${MODE}" in
  list) list_backups ;;
  restore)
    [[ -n "${ARGS[0]:-}" ]] || die "Usage: ducker restore <backup-id> [--vm]"
    do_restore "${ARGS[0]}"
    ;;
  backup) do_backup ;;
  *) die "Unknown backup mode: ${MODE}" ;;
esac
