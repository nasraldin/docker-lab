#!/usr/bin/env bash
# Live resource stats for Lima Docker.
# shellcheck shell=bash
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/common.sh"

export DOCKER_HOST="${DOCKER_HOST:-unix://${HOME}/.lima/${INSTANCE_NAME}/sock/docker.sock}"
unset DOCKER_CONTEXT || true

log "Lima"
limactl list 2> /dev/null || true
if lima_running; then
  echo
  limactl shell "${INSTANCE_NAME}" -- bash -lc 'echo "Guest: $(uname -m) cpus=$(nproc)"; free -h 2>/dev/null | head -2 || true; df -h / 2>/dev/null | tail -1 || true'
fi

echo
log "Docker stats (Ctrl+C to quit)"
if docker info > /dev/null 2>&1; then
  docker stats --no-stream 2> /dev/null || docker stats
else
  die "Docker server unreachable (is the VM running?)"
fi
