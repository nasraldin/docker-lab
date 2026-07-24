#!/usr/bin/env bash
# Deep diagnostics for docker-lab (host + Lima + Docker).
# shellcheck shell=bash
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/common.sh"

export DOCKER_HOST="${DOCKER_HOST:-unix://${HOME}/.lima/${INSTANCE_NAME}/sock/docker.sock}"
unset DOCKER_CONTEXT || true

section() { printf '\n==> %s\n' "$*"; }

section "Host"
printf '  uname:     %s %s\n' "$(uname -s)" "$(uname -m)"
printf '  brew:      %s\n' "$(command -v brew > /dev/null && brew --prefix || echo missing)"
printf '  limactl:   %s\n' "$(command -v limactl > /dev/null && limactl --version || echo missing)"
printf '  docker:    %s\n' "$(command -v docker > /dev/null && docker --version || echo missing)"
printf '  DOCKER_HOST=%s\n' "${DOCKER_HOST}"
printf '  DOCKER_CONTEXT=%s\n' "${DOCKER_CONTEXT:-<unset>}"

section "Lima"
if command -v limactl > /dev/null 2>&1; then
  limactl list || true
  if lima_exists; then
    printf '  status: %s\n' "$(lima_status || echo unknown)"
  fi
else
  echo "  limactl not installed"
fi

section "Docker"
if command -v docker > /dev/null 2>&1; then
  docker info --format '  Server={{.ServerVersion}} OS={{.OperatingSystem}} Arch={{.Architecture}} Rootless={{json .SecurityOptions}}' 2> /dev/null ||
    echo "  docker server unreachable"
  docker context ls 2> /dev/null || true
  docker buildx ls 2> /dev/null || true
else
  echo "  docker CLI not installed"
fi

section "Lab files"
printf '  ROOT_DIR=%s\n' "${ROOT_DIR}"
printf '  template=%s\n' "${LIMA_TEMPLATE}"
if [[ -f "${ROOT_DIR}/config/profiles/.active" ]]; then
  printf '  profile=%s\n' "$(tr -d '[:space:]' < "${ROOT_DIR}/config/profiles/.active")"
else
  printf '  profile=(none)\n'
fi

section "Recent hostagent errors (last 20)"
if [[ -f "${HOME}/.lima/${INSTANCE_NAME}/ha.stderr.log" ]]; then
  tail -n 20 "${HOME}/.lima/${INSTANCE_NAME}/ha.stderr.log" || true
else
  echo "  (no ha.stderr.log)"
fi

section "Hints"
echo "  ducker doctor --fix"
echo "  ducker verify"
echo "  docs/troubleshooting.md"
