#!/usr/bin/env bash
# Exercise cache preview without a Docker daemon.
set -euo pipefail

root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
export INSTANCE_NAME=review LIMA_HOME=/fixture/alternate
export DOCKER_HOST=tcp://unrelated.invalid:2375 DOCKER_CONTEXT=unrelated

limactl() {
  case "$*" in
    'list -q') printf 'review\n' ;;
    'list -f {{.Name}} {{.Status}}') printf 'review Running\n' ;;
    'shell review -- sudo systemctl start fstrim.service') printf 'trimmed fixture\n' ;;
    *) return 1 ;;
  esac
}

docker() {
  if [[ "$*" == *' buildx du '* ]]; then
    printf '%s\n' old-cache recent-cache active-cache shared-cache internal-cache frontend-cache never-used-cache
  elif [[ "$*" == "--host unix://${LIMA_HOME}/${INSTANCE_NAME}/sock/docker.sock buildx prune --builder default --filter until=24h --force" ]]; then
    printf 'pruned fixture\n'
  else
    return 1
  fi
}

curl() {
  [[ "$*" == *"--unix-socket ${LIMA_HOME}/${INSTANCE_NAME}/sock/docker.sock "* && "$*" == *'/system/df?type=build-cache' ]] || return 1
  python3 - <<'PY'
import json
from datetime import datetime, timedelta, timezone

now = datetime.now(timezone.utc)
records = [
    ("old-cache", now - timedelta(hours=48), False, False, "regular"),
    ("recent-cache", now - timedelta(hours=2), False, False, "regular"),
    ("active-cache", now - timedelta(hours=48), True, False, "regular"),
    ("shared-cache", now - timedelta(hours=48), False, True, "regular"),
    ("internal-cache", now - timedelta(hours=48), False, False, "internal"),
    ("frontend-cache", now - timedelta(hours=48), False, False, "frontend"),
    ("never-used-cache", None, False, False, "regular"),
]
print(json.dumps({"BuildCache": [
    {"ID": name, "LastUsedAt": last_used.strftime("%Y-%m-%dT%H:%M:%S.123456789Z") if last_used else None,
     "InUse": active, "Shared": shared, "Type": kind, "Size": 1024}
    for name, last_used, active, shared, kind in records
]}))
PY
}
env() {
  [[ "$1:$2:$3:$4:$5" == '-u:DOCKER_HOST:-u:DOCKER_CONTEXT:docker' ]] || return 1
  shift 5
  docker "$@"
}
export -f limactl docker curl env

output="$(bash "${root}/scripts/disk.sh" prune --older-than 24h)"
if [[ "${output}" != *old-cache* || "${output}" != *never-used-cache* ||
  "${output}" == *recent-cache* || "${output}" == *active-cache* ||
  "${output}" == *shared-cache* || "${output}" == *internal-cache* ||
  "${output}" == *frontend-cache* || "${output}" == *'pruned fixture'* ]]; then
  printf 'Unexpected cache preview:\n%s\n' "${output}" >&2
  exit 1
fi
output="$(bash "${root}/scripts/disk.sh" prune --older-than 24h --apply)"
if [[ "${output}" != *'pruned fixture'* || "${output}" != *'trimmed fixture'* ]]; then
  printf 'Apply did not prune the selected daemon and trim its guest:\n%s\n' "${output}" >&2
  exit 1
fi
printf 'Disk preview honors the cutoff and apply uses the selected instance\n'
