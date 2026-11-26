#!/usr/bin/env bash
# Exercise named-instance uninstall against disposable paths.
set -euo pipefail

root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
fixture="$(mktemp -d)"
trap 'rm -rf "${fixture}"' EXIT
export HOME="${fixture}/home" LIMA_HOME="${fixture}/alternate"
export INSTANCE_NAME=review DOCKER_CONTEXT=unrelated
export DOCKER_CALLS="${fixture}/docker-calls"
mkdir -p "${HOME}/.lima/${INSTANCE_NAME}" "${LIMA_HOME}/${INSTANCE_NAME}"

limactl() {
  case "$*" in
    'list -q') printf 'review\n' ;;
    'list -f {{.Name}} {{.Status}}') printf 'review Running\n' ;;
    'stop -f review' | 'delete -f review') ;;
    *) return 1 ;;
  esac
}
docker() {
  printf '%s %s %s\n' "${DOCKER_HOST}" "${DOCKER_CONTEXT:-unset}" "$*" >>"${DOCKER_CALLS}"
}
export -f limactl docker

bash "${root}/scripts/uninstall.sh" instance >/dev/null
if [[ ! -d "${HOME}/.lima/${INSTANCE_NAME}" || -e "${LIMA_HOME}/${INSTANCE_NAME}" ]] ||
  ! grep -Fxq "unix://${LIMA_HOME}/${INSTANCE_NAME}/sock/docker.sock unset system prune -a --volumes -f" "${DOCKER_CALLS}"; then
  printf 'Uninstall ran outside the selected Lima home\n' >&2
  exit 1
fi
printf 'Uninstall stays within the selected Lima home\n'
