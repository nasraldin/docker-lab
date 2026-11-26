#!/usr/bin/env bash
# Exercise backup and restore against disposable host paths.
set -euo pipefail

scripts="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
fixture="$(mktemp -d)"
trap 'rm -rf "${fixture}"' EXIT
export ROOT_DIR="${fixture}/lab"
export BACKUP_ROOT="${fixture}/backups"
export DOCKER_CONFIG_JSON="${fixture}/docker-config.json"
export ZSHRC_FILE="${fixture}/zshrc"
export LIMA_HOME="${fixture}/lima"
export INSTANCE_NAME=docker
export LIMA_TEMPLATE="${ROOT_DIR}/lima-docker.yaml"
unset BACKUP_MODE

mkdir -p "${ROOT_DIR}/config" "${ROOT_DIR}/scripts" "${LIMA_HOME}/occupied"
printf 'template\n' >"${LIMA_TEMPLATE}"
printf '{}\n' >"${ROOT_DIR}/config/daemon.json"
printf '{"credsStore":"osxkeychain"}\n' >"${DOCKER_CONFIG_JSON}"
printf 'exit 0\n' >"${ROOT_DIR}/scripts/install-shell-env.sh"

fail() {
  printf 'FAIL: %s\n' "$*" >&2
  exit 1
}

bash "${scripts}/backup.sh" >/dev/null
backups=("${BACKUP_ROOT}"/*)
id="${backups[0]##*/}"
bash "${scripts}/backup.sh" verify "${id}" >/dev/null || fail 'valid backup failed verification'

printf 'local changes\n' >"${LIMA_TEMPLATE}"
if bash "${scripts}/restore.sh" "${id}" --vm >/dev/null 2>&1; then
  fail 'VM restore accepted a config-only backup'
fi
[[ "$(cat "${LIMA_TEMPLATE}")" == 'local changes' ]] || fail 'missing VM archive changed lab config'

bash "${scripts}/restore.sh" "${id}" >/dev/null
[[ "$(cat "${LIMA_TEMPLATE}")" == template ]] || fail 'config restore did not restore the backed-up template'

printf 'changed\n' >>"${BACKUP_ROOT}/${id}/host/docker-config.json"
if bash "${scripts}/backup.sh" verify "${id}" >/dev/null 2>&1; then
  fail 'verification accepted a modified backup file'
fi

printf 'local changes\n' >"${LIMA_TEMPLATE}"
if bash "${scripts}/restore.sh" "${id}" >/dev/null 2>&1; then
  fail 'restore accepted a modified backup'
fi
[[ "$(cat "${LIMA_TEMPLATE}")" == 'local changes' ]] || fail 'restore changed the template before verification'

if bash "${scripts}/backup.sh" verify "../${id}" >/dev/null 2>&1; then
  fail 'verification accepted an ID that escapes the backup root'
fi

mkdir -p "${fixture}/bin" "${LIMA_HOME}/docker"
printf 'guest disk\n' >"${LIMA_HOME}/docker/disk"
printf 'plain: false\n' >"${LIMA_HOME}/docker/lima.yaml"
cat >"${fixture}/bin/limactl" <<'BASH'
#!/usr/bin/env bash
case "${*}" in
  'list -q') printf 'docker\n' ;;
  'list -f {{.Name}} {{.Status}}') printf 'docker Stopped\n' ;;
  *) printf '%s\n' "$*" >>"${LIMA_HOME}/unexpected-call"; exit 1 ;;
esac
BASH
chmod +x "${fixture}/bin/limactl"
export PATH="${fixture}/bin:${PATH}"
export BACKUP_ROOT="${fixture}/vm-backups"
bash "${scripts}/backup.sh" --vm >/dev/null
backups=("${BACKUP_ROOT}"/*)
id="${backups[0]##*/}"
bash "${scripts}/backup.sh" verify "${id}" >/dev/null

printf 'local changes\n' >"${LIMA_TEMPLATE}"
if result="$(bash "${scripts}/restore.sh" "${id}" --vm --into occupied 2>&1)"; then
  fail 'test restore accepted an occupied destination'
fi
[[ "${result}" == *'already exists'* ]] || fail "occupied destination failed unexpectedly: ${result}"
if result="$(bash "${scripts}/restore.sh" "${id}" --vm --into docker 2>&1)"; then
  fail 'test restore accepted the default Docker instance'
fi
[[ "${result}" == *'distinct from the lab and backup instances'* ]] || fail "default instance failed unexpectedly: ${result}"
[[ ! -f "${LIMA_HOME}/unexpected-call" ]] || fail 'test restore tried to mutate an existing Lima instance'
[[ "$(cat "${LIMA_TEMPLATE}")" == 'local changes' ]] || fail 'test restore modified lab config'

printf 'changed\n' >>"${BACKUP_ROOT}/${id}/lima-docker.tar.gz"
if bash "${scripts}/backup.sh" verify "${id}" >/dev/null 2>&1; then
  fail 'verification accepted a modified VM archive'
fi

printf 'Backup regression checks passed\n'
