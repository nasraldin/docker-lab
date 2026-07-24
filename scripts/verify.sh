#!/usr/bin/env bash
# End-to-end health checks for the Lima Docker stack.
# shellcheck shell=bash
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/common.sh"

export DOCKER_HOST="${DOCKER_HOST:-unix://${HOME}/.lima/${INSTANCE_NAME}/sock/docker.sock}"
unset DOCKER_CONTEXT || true

failures=0
check() {
  local name="$1"
  shift
  if "$@"; then
    printf '  [OK]   %s\n' "${name}"
  else
    printf '  [FAIL] %s\n' "${name}" >&2
    failures=$((failures + 1))
  fi
}

has_cmd() { command -v "$1" > /dev/null 2>&1; }
compose_ok() { docker compose version > /dev/null 2>&1; }
buildx_plugin_ok() { docker buildx version > /dev/null 2>&1; }
cli_plugins_ok() {
  python3 - "${DOCKER_CONFIG_JSON}" "${CLI_PLUGINS_DIR}" << 'PY'
import json, sys
from pathlib import Path
p, want = Path(sys.argv[1]), sys.argv[2]
cfg = json.loads(p.read_text())
sys.exit(0 if want in cfg.get("cliPluginsExtraDirs", []) else 1)
PY
}
guest_arch_ok() {
  local arch
  arch="$(limactl shell "${INSTANCE_NAME}" -- uname -m 2> /dev/null | tr -d '\r')"
  [[ "${arch}" == "aarch64" ]]
}
docker_info_ok() { docker info > /dev/null 2>&1; }
snapshotter_ok() {
  # Avoid `grep -q | pipefail` SIGPIPE false failures against `docker info`
  local info
  info="$(docker info 2> /dev/null || true)"
  [[ "${info}" == *"io.containerd.snapshotter"* ]]
}
rootless_ok() {
  local opts
  opts="$(docker info --format '{{json .SecurityOptions}}' 2> /dev/null || true)"
  [[ "${opts}" == *rootless* ]]
}
buildx_default_ok() {
  docker buildx inspect default > /dev/null 2>&1
}
hello_ok() { docker run --rm hello-world > /dev/null 2>&1; }

log "Verifying host tools"
check "limactl present" has_cmd limactl
check "docker present" has_cmd docker
check "docker compose plugin" compose_ok
check "docker buildx plugin" buildx_plugin_ok
check "cliPluginsExtraDirs configured" cli_plugins_ok

log "Verifying Lima instance '${INSTANCE_NAME}'"
check "instance exists" lima_exists
check "instance Running" lima_running
check "guest arch aarch64" guest_arch_ok

log "Verifying Docker Engine via DOCKER_HOST=${DOCKER_HOST}"
check "docker server reachable" docker_info_ok
check "storage uses containerd snapshotter" snapshotter_ok
check "rootless security option" rootless_ok
check "buildx default builder healthy" buildx_default_ok
check "hello-world" hello_ok

if [[ "${failures}" -ne 0 ]]; then
  die "${failures} verification check(s) failed"
fi

log "All checks passed"
docker version --format 'Client {{.Client.Version}} / Server {{.Server.Version}}'
docker info --format 'OS={{.OperatingSystem}} Arch={{.Architecture}}'
