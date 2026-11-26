#!/usr/bin/env bash
# Create/start the Lima Docker instance from the Debian 13 template.
# shellcheck shell=bash
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/common.sh"

require_cmd limactl
require_file "${LIMA_TEMPLATE}"
trim_config="${ROOT_DIR}/config/fstrim-hourly.conf"
require_file "${trim_config}"

if lima_running; then
  log "Instance '${INSTANCE_NAME}' already Running — skipping start"
elif lima_exists; then
  log "Starting existing instance '${INSTANCE_NAME}'"
  limactl start --tty=false "${INSTANCE_NAME}"
else
  log "Creating instance '${INSTANCE_NAME}' from ${LIMA_TEMPLATE}"
  limactl start --tty=false --name="${INSTANCE_NAME}" "${LIMA_TEMPLATE}"
fi

limactl list "${INSTANCE_NAME}"
lima_running || die "Instance '${INSTANCE_NAME}' failed to reach Running state"

# Return freed guest blocks to the host before the sparse disk fills macOS.
trim_dropin="/etc/systemd/system/fstrim.timer.d/50-docker-lab-hourly.conf"
if ! limactl shell "${INSTANCE_NAME}" -- cmp -s "${trim_dropin}" - <"${trim_config}"; then
  log "Installing hourly guest disk trim schedule"
  limactl shell "${INSTANCE_NAME}" -- sudo install -d -m 0755 "${trim_dropin%/*}"
  limactl shell "${INSTANCE_NAME}" -- sudo tee "${trim_dropin}" <"${trim_config}" >/dev/null
  limactl shell "${INSTANCE_NAME}" -- sudo systemctl daemon-reload
  limactl shell "${INSTANCE_NAME}" -- sudo systemctl enable fstrim.timer
  limactl shell "${INSTANCE_NAME}" -- sudo systemctl restart fstrim.timer
fi

log "Lima instance ready"
