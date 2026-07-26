#!/usr/bin/env bash
# Benchmark disk I/O, image pull, and container start for the Lima Docker lab.
# shellcheck shell=bash
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/common.sh"

export DOCKER_HOST="${DOCKER_HOST:-unix://${HOME}/.lima/${INSTANCE_NAME}/sock/docker.sock}"
unset DOCKER_CONTEXT || true

require_cmd limactl docker
lima_running || die "Lima instance '${INSTANCE_NAME}' is not Running (ducker start / ducker install)"

elapsed_ms() {
  # macOS date +%s%N is not portable — use python
  python3 -c 'import time; print(int(time.time() * 1000))'
}

run_timed() {
  local label="$1"
  shift
  local start end ms
  printf '  · %s ... ' "${label}"
  start="$(elapsed_ms)"
  if "$@"; then
    end="$(elapsed_ms)"
    ms=$((end - start))
    printf 'OK (%d ms)\n' "${ms}"
  else
    end="$(elapsed_ms)"
    ms=$((end - start))
    printf 'FAIL (%d ms)\n' "${ms}"
    return 1
  fi
}

log "Docker Lab benchmark (instance=${INSTANCE_NAME})"
echo

failures=0

# 1) Guest disk write (~256 MiB)
if ! run_timed "guest disk write (dd 256M)" \
  limactl shell "${INSTANCE_NAME}" -- \
  bash -lc 'dd if=/dev/zero of=/tmp/ducker-bench.img bs=1M count=256 conv=fsync status=none && rm -f /tmp/ducker-bench.img'; then
  failures=$((failures + 1))
fi

# 2) Image pull
docker rmi alpine:latest >/dev/null 2>&1 || true
if ! run_timed "docker pull alpine:latest" docker pull alpine:latest >/dev/null; then
  failures=$((failures + 1))
fi

# 3) Container start
if ! run_timed "docker run hello-world" docker run --rm hello-world >/dev/null; then
  failures=$((failures + 1))
fi

# 4) Short CPU stress (optional — network/image may already be cached)
if ! run_timed "stress-ng cpu 2 / 10s" \
  docker run --rm ghcr.io/colinianking/stress-ng --cpu 2 --timeout 10s --metrics-brief >/dev/null; then
  warn "stress-ng step failed (network or image) — other timings still useful"
  failures=$((failures + 1))
fi

echo
if [[ "${failures}" -ne 0 ]]; then
  die "${failures} benchmark step(s) failed"
fi
log "Benchmark complete"
