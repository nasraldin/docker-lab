#!/usr/bin/env bash
# Backup and restore the lab configuration and optional Lima VM.
# shellcheck shell=bash
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/common.sh"

BACKUP_ROOT="${BACKUP_ROOT:-${HOME}/.local/share/docker-lab/backups}"
LIMA_HOME="${LIMA_HOME:-${HOME}/.lima}"
MANIFEST=SHA256SUMS

usage() {
  cat <<'HELP'
Usage:
  ducker backup [--vm]
  ducker backup list
  ducker backup verify <backup-id>
  ducker restore <backup-id> [--vm]
  ducker restore <backup-id> --vm --into <new-instance>

Stores snapshots under ~/.local/share/docker-lab/backups/<id>/
HELP
}

backup_dir() {
  local id="$1"
  [[ "${id}" =~ ^[0-9]{8}-[0-9]{6}$ ]] || die "Invalid backup ID: ${id}"
  local dir="${BACKUP_ROOT}/${id}"
  [[ -d "${dir}" && ! -L "${dir}" ]] || die "Backup not found: ${id} (ducker backup list)"
  printf '%s\n' "${dir}"
}

list_backups() {
  local dir bits header=0
  for dir in "${BACKUP_ROOT}"/*; do
    [[ -d "${dir}" && ! -L "${dir}" && -f "${dir}/BACKUP_ID" ]] || continue
    if [[ "${header}" -eq 0 ]]; then
      printf '%-20s %s\n' "ID" "CONTENTS"
      header=1
    fi
    bits=config
    [[ -f "${dir}/lima-docker.tar.gz" ]] && bits=config+vm
    printf '%-20s %s\n' "${dir##*/}" "${bits}"
  done
  if [[ "${header}" -eq 0 ]]; then
    log "No backups yet (ducker backup)"
  fi
}

# Rebuild the manifest from known paths. Never interpret paths from the manifest.
checksum_backup() (
  cd "$1" || exit 1
  require_cmd shasum
  local folder file
  for folder in config host; do
    [[ ! -L "${folder}" ]] || die "Backup contains a symlink: ${folder}"
  done
  require_file BACKUP_ID lima-docker.yaml config/daemon.json
  for file in BACKUP_ID lima-docker.yaml config/daemon.json config.env profile.active \
    host/docker-config.json host/zshrc.snippet lima-docker.tar.gz; do
    if [[ -e "${file}" || -L "${file}" ]]; then
      [[ -f "${file}" && ! -L "${file}" ]] || die "Invalid backup file: ${file}"
      shasum -a 256 "${file}" || exit 1
    fi
  done
)

verify_backup() {
  local dir="$1" id="${1##*/}" checksums
  [[ -f "${dir}/${MANIFEST}" && ! -L "${dir}/${MANIFEST}" ]] ||
    die "Backup ${id} has no checksum manifest. Create a new backup with ducker backup."
  checksums="$(checksum_backup "${dir}")" || die "Could not read backup ${id}"
  printf '%s\n' "${checksums}" | cmp -s - "${dir}/${MANIFEST}" ||
    die "Checksum verification failed for backup ${id}"
  [[ "$(cat "${dir}/BACKUP_ID")" == "${id}" ]] || die "Backup ID mismatch: ${id}"
}

do_backup() (
  local include_vm="$1" id dir stage status
  umask 077
  id="$(date +%Y%m%d-%H%M%S)"
  dir="${BACKUP_ROOT}/${id}"
  stage="${BACKUP_ROOT}/.backup.${id}"
  mkdir -p "${BACKUP_ROOT}"
  mkdir "${stage}" || die "Backup ${id} is already in progress. Retry in a second."
  trap 'rm -rf "${stage}"' EXIT
  [[ ! -e "${dir}" && ! -L "${dir}" ]] || die "Backup ${id} already exists. Retry in a second."
  mkdir "${stage}/config" "${stage}/host"

  log "Backing up lab config → ${dir}"
  cp "${LIMA_TEMPLATE}" "${stage}/lima-docker.yaml"
  cp "${ROOT_DIR}/config/daemon.json" "${stage}/config/daemon.json"
  if [[ -f "${ROOT_DIR}/config.env" ]]; then
    cp "${ROOT_DIR}/config.env" "${stage}/config.env"
  fi
  if [[ -f "${ROOT_DIR}/config/profiles/.active" ]]; then
    cp "${ROOT_DIR}/config/profiles/.active" "${stage}/profile.active"
  fi
  if [[ -f "${DOCKER_CONFIG_JSON}" ]]; then
    cp "${DOCKER_CONFIG_JSON}" "${stage}/host/docker-config.json"
  fi
  if [[ -f "${ZSHRC_FILE}" ]] && grep -qF "${MARKER_BEGIN}" "${ZSHRC_FILE}"; then
    awk -v b="${MARKER_BEGIN}" -v e="${MARKER_END}" '
      $0 == b {p=1}
      p {print}
      $0 == e {p=0}
    ' "${ZSHRC_FILE}" >"${stage}/host/zshrc.snippet"
  fi

  if [[ "${include_vm}" -eq 1 ]]; then
    require_cmd limactl
    [[ "${INSTANCE_NAME}" =~ ^[a-zA-Z0-9][a-zA-Z0-9_-]*$ ]] || die "Invalid Lima instance name"
    status="$(lima_status)" || die "No Lima instance '${INSTANCE_NAME}' for --vm backup"
    if [[ "${status}" == Running ]]; then
      log "Stopping instance before VM archive"
      limactl stop "${INSTANCE_NAME}"
      status="$(lima_status)"
    fi
    [[ "${status}" == Stopped ]] || die "Lima instance '${INSTANCE_NAME}' must be stopped to back up its disk"
    [[ -f "${LIMA_HOME}/${INSTANCE_NAME}/disk" || -f "${LIMA_HOME}/${INSTANCE_NAME}/diffdisk" ]] ||
      die "Lima instance '${INSTANCE_NAME}' has no disk to back up"
    log "Archiving ${LIMA_HOME}/${INSTANCE_NAME} (this can be large)"
    COPYFILE_DISABLE=1 tar --exclude='*.sock' --exclude='*.pid' -C "${LIMA_HOME}" \
      -czf "${stage}/lima-docker.tar.gz" "${INSTANCE_NAME}"
  fi

  printf '%s\n' "${id}" >"${stage}/BACKUP_ID"
  checksum_backup "${stage}" >"${stage}/${MANIFEST}"
  mv "${stage}" "${dir}"
  trap - EXIT
  log "Backup complete: ${id}"
  log "Restore with: ducker restore ${id}"
)

# Accept a single Lima instance root and the disk aliases used by older Lima
# releases. Reject all other links, special files, and paths outside the root.
inspect_vm_archive() {
  python3 - "$1" <<'PY'
import re
import sys
import tarfile
from pathlib import PurePosixPath

try:
    with tarfile.open(sys.argv[1], "r|gz") as archive:
        root = None
        members = {}
        for member in archive:
            name = member.name
            parts = PurePosixPath(name).parts
            if not parts or name != "/".join(parts) or ".." in parts:
                raise ValueError("invalid archive member path")
            if root is None:
                root = parts[0]
                if not re.fullmatch(r"[a-zA-Z0-9][a-zA-Z0-9_-]*", root):
                    raise ValueError("invalid instance name")
            if parts[0] != root or name in members:
                raise ValueError("archive has multiple instance roots or duplicate entries")
            if member.issym():
                aliases = {"disk": "diffdisk", "iso": "basedisk"}
                if len(parts) != 2 or aliases.get(parts[1]) != member.linkname:
                    raise ValueError("archive contains an unexpected symbolic link")
            elif not (member.isfile() or member.isdir()):
                raise ValueError("archive contains a special file or hard link")
            members[name] = member
        if root is None or root not in members or not members[root].isdir():
            raise ValueError("archive does not contain a Lima instance directory")
        for name, member in members.items():
            for parent in PurePosixPath(name).parents:
                parent_entry = members.get(str(parent))
                if parent_entry is not None and not parent_entry.isdir():
                    raise ValueError("archive file shadows a parent directory")
            if member.issym():
                target = members.get(f"{root}/{member.linkname}")
                if target is None or not target.isfile():
                    raise ValueError("archive disk alias has no regular file target")
        config = members.get(f"{root}/lima.yaml")
        if config is None or not config.isfile():
            raise ValueError("archive does not contain a Lima configuration")
        disk = members.get(f"{root}/disk") or members.get(f"{root}/diffdisk")
        if disk is None or not (disk.isfile() or disk.issym()):
            raise ValueError("archive does not contain a Lima VM disk")
        print(root)
except (OSError, ValueError, tarfile.TarError) as exc:
    sys.exit(f"Invalid Lima VM archive: {exc}")
PY
}

extract_vm_archive() {
  COPYFILE_DISABLE=1 tar --no-same-owner --no-same-permissions -xzf "$1" -C "$2" "${@:3}"
}

restore_boot_script() {
  cat <<'BOOT'
#!/bin/sh
set -eu
stale='^[[:blank:]]*(lima-[^[:blank:]]+|vz-rosetta)[[:blank:]]+[^[:blank:]]+[[:blank:]]+virtiofs[[:blank:]]'
if grep -Eq "$stale" /etc/fstab; then
  sed -E -i "/$stale/d" /etc/fstab
  systemctl daemon-reload
  systemctl --no-block default
fi
BOOT
}

check_test_instance() {
  limactl list -f '{{json .Config}}' "$1" | python3 -c '
import json
import sys

config = json.load(sys.stdin)
blocked = ("mounts", "additionalDisks", "blockDevices", "networks")
forwards = config.get("portForwards") or []
provision = config.get("provision") or []
if (config.get("vmType") != "vz"
        or any(config.get(key) for key in blocked)
        or config.get("ssh", {}).get("forwardAgent")
        or config.get("vmOpts", {}).get("vz", {}).get("rosetta", {}).get("enabled")
        or config.get("networkOpts", {}).get("hostLoopback") is not False
        or len(provision) != 1 or provision[0].get("mode") != "boot"
        or provision[0].get("script", "").strip() != sys.argv[1].strip()
        or len(forwards) != 1 or forwards[0].get("ignore") is not True
        or forwards[0].get("proto") != "any"
        or forwards[0].get("guestPortRange") != [1, 65535]):
    sys.exit("Lima settings would expose host resources to the test instance")
' "$2"
}

test_restore() (
  local archive="$1" source="$2" target="$3" stage guest_disk disk_size boot_script provision
  [[ "${target}" =~ ^[a-z0-9][a-z0-9-]*$ ]] || die "Invalid test instance name: ${target}"
  [[ "${target}" != "${INSTANCE_NAME}" && "${target}" != docker && "${target}" != "${source}" ]] ||
    die "Choose a new instance name distinct from the lab and backup instances"
  [[ ! -e "${LIMA_HOME}/${target}" && ! -L "${LIMA_HOME}/${target}" ]] ||
    die "Lima instance '${target}' already exists"

  mkdir -p "${LIMA_HOME}"
  stage="$(mktemp -d "${LIMA_HOME}/.ducker-restore.XXXXXXXX")"
  trap 'rm -rf "${stage}"' EXIT
  # Full restores use the archived configuration. Test restores only import
  # disk data and use a fresh, mount-free Lima configuration.
  extract_vm_archive "${archive}" "${stage}" "${source}"
  guest_disk="${stage}/${source}/disk"
  if [[ ! -f "${guest_disk}" ]]; then
    guest_disk="${stage}/${source}/diffdisk"
  fi
  [[ -f "${guest_disk}" ]] || die "Backup has no Lima VM disk"
  disk_size="$(python3 -c 'import os, sys; print(os.path.getsize(sys.argv[1]))' "${guest_disk}")"

  boot_script="$(restore_boot_script)"
  provision="$(jq -cn --arg script "$boot_script" '[{mode:"boot",script:$script}]')"
  limactl create --tty=false --name="${target}" --mount-none --set ".provision = ${provision}" - <<YAML
minimumLimaVersion: 2.0.0
base:
  - template:_images/debian-13
arch: aarch64
vmType: vz
cpus: 2
memory: 4GiB
disk: ${disk_size}B
containerd:
  system: false
  user: false
vmOpts:
  vz:
    rosetta:
      enabled: false
portForwards:
  - guestPortRange: [1, 65535]
    ignore: true
    proto: any
ssh:
  loadDotSSHPubKeys: false
  forwardAgent: false
networkOpts:
  hostLoopback: false
YAML
  check_test_instance "${target}" "$boot_script"
  # Keep only the guest's boot disk and EFI variables. Lima creates fresh
  # host-side connections and a new Virtualization.framework identifier.
  if [[ -L "${guest_disk}" ]]; then
    guest_disk="${stage}/${source}/$(readlink "${guest_disk}")"
  fi
  mv "${guest_disk}" "${LIMA_HOME}/${target}/disk"
  if [[ -f "${stage}/${source}/vz-efi" ]]; then
    mv "${stage}/${source}/vz-efi" "${LIMA_HOME}/${target}/vz-efi"
  fi
  limactl start --timeout 120s --tty=false "${target}"
  limactl shell --workdir / "${target}" -- sh -c \
    'env -u DOCKER_CONTEXT -u DOCKER_HOST docker --host "unix:///run/user/$(id -u)/docker.sock" info --format "{{.ServerVersion}}"'
  log "Test restore ready: ${target}"
  log "Inspect with: limactl shell ${target}"
)

do_restore() (
  local id="$1" include_vm="$2" target="$3" dir archive source stage=''
  dir="$(backup_dir "${id}")" || exit 1
  if [[ -n "${target}" || -e "${dir}/${MANIFEST}" || -L "${dir}/${MANIFEST}" ]]; then
    verify_backup "${dir}"
  else
    warn "Backup ${id} predates checksums. Restore only from a trusted backup."
    # Enforce the same file-shape checks for older config-only backups.
    checksum_backup "${dir}" >/dev/null
  fi

  if [[ "${include_vm}" -eq 1 ]]; then
    require_cmd limactl python3
    [[ -z "${target}" ]] || require_cmd jq
    archive="${dir}/lima-docker.tar.gz"
    [[ -f "${archive}" && ! -L "${archive}" ]] ||
      die "Backup ${id} has no VM archive (re-run backup with --vm)"
    source="$(inspect_vm_archive "${archive}")" || exit 1
    if [[ -n "${target}" ]]; then
      test_restore "${archive}" "${source}" "${target}"
      exit
    fi
    [[ "${source}" == "${INSTANCE_NAME}" ]] || die "Backup VM is '${source}', not '${INSTANCE_NAME}'. Use --into to test it."
    mkdir -p "${LIMA_HOME}"
    stage="$(mktemp -d "${LIMA_HOME}/.ducker-restore.XXXXXXXX")"
    trap 'rm -rf "${stage}"' EXIT
    extract_vm_archive "${archive}" "${stage}" "${source}"
  fi

  log "Restoring config from ${dir}"
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

  if [[ "${include_vm}" -eq 1 ]]; then
    if lima_exists; then
      log "Deleting existing instance '${INSTANCE_NAME}'"
      limactl delete -f "${INSTANCE_NAME}"
    fi
    [[ ! -e "${LIMA_HOME}/${source}" && ! -L "${LIMA_HOME}/${source}" ]] ||
      die "Restore destination still exists: ${LIMA_HOME}/${source}"
    mv "${stage}/${source}" "${LIMA_HOME}/${source}"
    log "Start with: ducker start && ducker verify"
  else
    log "Config restored. Re-apply guest daemon if VM is running: ducker daemon"
  fi
)

case "${1:-}" in
  -h | --help | help)
    usage
    exit 0
    ;;
esac

if [[ "${BACKUP_MODE:-}" == restore || "${1:-}" == restore ]]; then
  if [[ "${1:-}" == restore ]]; then shift; fi
  [[ "${#}" -ge 1 ]] || die "Usage: ducker restore <backup-id> [--vm [--into <new-instance>]]"
  id="$1"
  shift
  include_vm=0
  target=''
  while [[ "${#}" -gt 0 ]]; do
    case "$1" in
      --vm) include_vm=1 ;;
      --into)
        [[ "${#}" -ge 2 && -n "$2" ]] || die "--into requires a new instance name"
        target="$2"
        shift
        ;;
      *) die "Unknown restore argument: $1" ;;
    esac
    shift
  done
  [[ -z "${target}" || "${include_vm}" -eq 1 ]] || die "--into requires --vm"
  do_restore "${id}" "${include_vm}" "${target}"
  exit
fi

case "${1:-}" in
  list | ls)
    [[ "${#}" -eq 1 ]] || die "Usage: ducker backup list"
    list_backups
    ;;
  verify)
    [[ "${#}" -eq 2 ]] || die "Usage: ducker backup verify <backup-id>"
    dir="$(backup_dir "$2")"
    verify_backup "${dir}"
    log "Backup verified: $2"
    ;;
  "" | --vm | backup)
    if [[ "${1:-}" == backup ]]; then shift; fi
    case "${*}" in
      "") do_backup 0 ;;
      --vm) do_backup 1 ;;
      *) die "Usage: ducker backup [--vm]" ;;
    esac
    ;;
  *) die "Unknown backup argument: $1" ;;
esac
