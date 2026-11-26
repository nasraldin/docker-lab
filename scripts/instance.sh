#!/usr/bin/env bash
# Manage named Lima instances without changing the global Docker context.
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/common.sh"

register_context() {
  local name="lima-${INSTANCE_NAME}" socket host
  socket="$(lima_docker_host)"
  if host="$(docker context inspect "$name" --format '{{.Endpoints.docker.Host}}' 2>/dev/null)"; then
    [[ "$host" == "$socket" ]] || die "Context '$name' already points to a different Docker endpoint"
  else
    docker context create "$name" --docker "host=$socket"
  fi
  printf 'Use: env -u DOCKER_HOST -u DOCKER_CONTEXT docker --context %s ps\n' "$name"
}

usage() {
  printf '%s\n' 'Usage: ducker instance list | create NAME [dev|ci] [MOUNT_DIRECTORY] | context NAME'
}

case "${1:-list}" in
  list)
    [[ $# -le 1 ]] || die "Usage: ducker instance list"
    limactl list
    ;;
  create)
    [[ $# -ge 2 && $# -le 4 ]] || {
      usage
      exit 1
    }
    export INSTANCE_NAME="$2"
    valid_instance_name "$INSTANCE_NAME" || die "Invalid Lima instance name"
    [[ "$INSTANCE_NAME" != docker ]] || die "Use ducker install for the default docker instance"
    profile="${3:-dev}"
    case "$profile" in
      dev) budget=(--cpus=2 --memory=4 --disk=40) ;;
      ci) budget=(--cpus=4 --memory=8 --disk=80) ;;
      *) die "Unknown instance profile '$profile'; choose dev or ci" ;;
    esac
    mounts=(--mount-none)
    if [[ -n "${4:-}" ]]; then
      mount_dir="$(cd -P -- "$4" && pwd -P)" || die "Mount directory does not exist"
      home_dir="$(cd -P -- "$HOME" && pwd -P)"
      [[ "$mount_dir" != / && "$mount_dir" != "$home_dir" ]] ||
        die "Choose a dedicated project directory for the instance mount"
      [[ "$mount_dir" != *:* && "$mount_dir" != *,* && "$mount_dir" != *$'\n'* ]] ||
        die "Mount directory cannot contain a colon, comma, or newline"
      mounts=(--mount-only "${mount_dir}:w")
    fi
    require_cmd limactl docker
    if lima_exists; then
      die "Instance '$INSTANCE_NAME' already exists"
    fi
    limactl start --tty=false --name="$INSTANCE_NAME" "${budget[@]}" "${mounts[@]}" "$LIMA_TEMPLATE"
    /bin/bash "$ROOT_DIR/scripts/install-lima.sh"
    register_context
    ;;
  context)
    [[ $# == 2 ]] || {
      usage
      exit 1
    }
    INSTANCE_NAME="$2"
    valid_instance_name "$INSTANCE_NAME" || die "Invalid Lima instance name"
    lima_exists || die "Lima instance '$INSTANCE_NAME' does not exist"
    register_context
    ;;
  -h | --help | help) usage ;;
  *)
    usage
    exit 1
    ;;
esac
