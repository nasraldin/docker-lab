#!/usr/bin/env bash
# Start, inspect, and stop Compose labs on the selected Lima Docker daemon.
# shellcheck shell=bash
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/common.sh"

usage() {
  cat <<'EOF'
Usage: ducker lab start|status|stop [data]
       ducker lab stop [data] --volumes

The data lab starts PostgreSQL and Redis and waits for both to become healthy.
Set LAB_POSTGRES_PORT (default 15432) or LAB_REDIS_PORT (default 16379) on start.
Stopping keeps the data volumes. Add --volumes to delete the lab's data.
EOF
}

action="${1:-help}"
if [[ $# -gt 0 ]]; then
  shift
fi
if [[ "${1:-}" == data ]]; then
  shift
fi

compose_args=()
case "${action}" in
  start) compose_args=(up --detach --wait --wait-timeout 120) ;;
  status) compose_args=(ps --all) ;;
  stop)
    compose_args=(down)
    if [[ "${1:-}" == --volumes ]]; then
      compose_args+=(--volumes)
      shift
    fi
    ;;
  help | -h | --help)
    usage
    exit 0
    ;;
  *) die "Unknown lab action '${action}'. Run: ducker lab help" ;;
esac
[[ $# == 0 ]] || die "Unexpected lab argument '${1}'. Run: ducker lab help"

validate_port() {
  local name="$1" value="$2"
  if [[ ! "${value}" =~ ^[1-9][0-9]{0,4}$ ]] || ((value > 65535)); then
    die "${name} must be a port number between 1 and 65535"
  fi
}

export LAB_POSTGRES_PORT="${LAB_POSTGRES_PORT:-15432}"
export LAB_REDIS_PORT="${LAB_REDIS_PORT:-16379}"
if [[ "${action}" == start ]]; then
  validate_port LAB_POSTGRES_PORT "${LAB_POSTGRES_PORT}"
  validate_port LAB_REDIS_PORT "${LAB_REDIS_PORT}"
  [[ "${LAB_POSTGRES_PORT}" != "${LAB_REDIS_PORT}" ]] || die 'The lab needs two different ports'
else
  # Compose loads the port mappings even for commands that do not publish ports.
  export LAB_POSTGRES_PORT=15432 LAB_REDIS_PORT=16379
fi

compose_file="${ROOT_DIR}/apps/labs/data/compose.yaml"
require_file "${compose_file}"
require_cmd limactl docker
lima_running || die "Lima instance '${INSTANCE_NAME}' is not Running — run: ducker start"

DOCKER_HOST="$(lima_docker_host)"
export DOCKER_HOST
unset DOCKER_CONTEXT COMPOSE_REMOVE_ORPHANS
docker compose version >/dev/null 2>&1 || die 'Docker Compose is unavailable — run: ducker deps'
docker info >/dev/null 2>&1 || die "Docker daemon not reachable via ${DOCKER_HOST}"

docker compose --project-name ducker-lab-data --env-file /dev/null \
  -f "${compose_file}" "${compose_args[@]}"

if [[ "${action}" == start ]]; then
  log "PostgreSQL: 127.0.0.1:${LAB_POSTGRES_PORT} | Redis: 127.0.0.1:${LAB_REDIS_PORT}"
fi
