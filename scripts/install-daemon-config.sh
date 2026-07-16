#!/usr/bin/env bash
# Apply rootless Docker daemon.json inside the Lima guest.
# shellcheck shell=bash
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/common.sh"

require_cmd limactl
require_file "${ROOT_DIR}/config/daemon.json"
lima_running || die "Instance '${INSTANCE_NAME}' is not Running — run: make lima-start"

GUEST_HOME="$(limactl shell "${INSTANCE_NAME}" -- bash -lc 'printf %s "$HOME"')"
[[ -n "${GUEST_HOME}" ]] || die "Could not resolve guest HOME"

log "Applying guest rootless daemon.json → ${INSTANCE_NAME}:${GUEST_HOME}/.config/docker/daemon.json"
limactl shell "${INSTANCE_NAME}" -- mkdir -p "${GUEST_HOME}/.config/docker"
limactl copy "${ROOT_DIR}/config/daemon.json" \
  "${INSTANCE_NAME}:${GUEST_HOME}/.config/docker/daemon.json"
limactl shell "${INSTANCE_NAME}" -- bash -lc '
  set -euo pipefail
  systemctl --user restart docker
  systemctl --user --quiet is-active docker
  echo "guest daemon.json:"
  cat "${HOME}/.config/docker/daemon.json"
'

log "Guest Docker daemon config applied"
