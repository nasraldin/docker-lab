#!/usr/bin/env bash
# Apply rootless Docker daemon.json inside the Lima guest.
# shellcheck shell=bash
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/common.sh"

require_cmd limactl
require_file "${ROOT_DIR}/config/daemon.json"
lima_running || die "Instance '${INSTANCE_NAME}' is not Running — run: make lima"

log "Applying managed daemon settings in '${INSTANCE_NAME}'"
limactl shell "${INSTANCE_NAME}" -- bash -c '
  set -euo pipefail
  config_dir="${XDG_CONFIG_HOME:-${HOME}/.config}/docker"
  mkdir -p "$config_dir"
  config="$config_dir/daemon.json"
  candidate="$(mktemp "$config_dir/.daemon.XXXXXXXX")"
  trap "rm -f -- \"\$candidate\"" EXIT
  if [[ -f "$config" ]]; then
    # Keep guest-specific settings outside the lab-managed defaults.
    jq -s ".[0] * .[1]" "$config" - >"$candidate"
  else
    cat >"$candidate"
  fi
  dockerd --validate --config-file "$candidate"
  if ! cmp -s "$candidate" "$config"; then
    mv -f -- "$candidate" "$config"
    systemctl --user restart docker
  elif ! systemctl --user --quiet is-active docker; then
    systemctl --user start docker
  fi
  systemctl --user --quiet is-active docker
' <"${ROOT_DIR}/config/daemon.json"

log "Guest Docker daemon config applied"
