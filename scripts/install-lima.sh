#!/usr/bin/env bash
# Create/start the Lima Docker instance from the Debian 13 template.
# shellcheck shell=bash
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/common.sh"

require_cmd limactl
require_file "${LIMA_TEMPLATE}"

if lima_running; then
  log "Instance '${INSTANCE_NAME}' already Running — skipping start"
  limactl list "${INSTANCE_NAME}"
  exit 0
fi

if lima_exists; then
  log "Starting existing instance '${INSTANCE_NAME}'"
  limactl start --tty=false "${INSTANCE_NAME}"
else
  log "Creating instance '${INSTANCE_NAME}' from ${LIMA_TEMPLATE}"
  limactl start --tty=false --name="${INSTANCE_NAME}" "${LIMA_TEMPLATE}"
fi

limactl list "${INSTANCE_NAME}"
lima_running || die "Instance '${INSTANCE_NAME}' failed to reach Running state"
log "Lima instance ready"
