#!/usr/bin/env bash
# Exercise lab command routing without a VM or Docker daemon.
set -euo pipefail

root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
tmp="$(mktemp -d)"
trap 'rm -rf "${tmp}"' EXIT

cat >"${tmp}/limactl" <<'EOF'
#!/usr/bin/env bash
[[ "${LIMA_HOME}" == "${LAB_TEST_DIR}/alternate lima" ]] || exit 1
case "${2:-}" in
  -q) printf 'alternate\n' ;;
  -f) printf 'alternate %s\n' "${LAB_TEST_LIMA_STATUS:-Running}" ;;
  *) exit 1 ;;
esac
EOF

cat >"${tmp}/docker" <<'EOF'
#!/usr/bin/env bash
touch "${LAB_TEST_DIR}/docker-called"
[[ "${DOCKER_HOST}" == "unix://${LIMA_HOME}/alternate/sock/docker.sock" && -z "${DOCKER_CONTEXT:-}" ]] || exit 1
[[ "${COMPOSE_REMOVE_ORPHANS:-}" != 'true' ]] || exit 1
[[ "$*" != 'info' && "$*" != 'compose version' ]] || exit 0
printf '%s\n' "$@" >"${LAB_TEST_DIR}/args"
printf '%s\n' "${LAB_POSTGRES_PORT}" "${LAB_REDIS_PORT}" >"${LAB_TEST_DIR}/ports"
EOF

chmod +x "${tmp}/limactl" "${tmp}/docker"
export PATH="${tmp}:${PATH}"
export LAB_TEST_DIR="${tmp}" LIMA_HOME="${tmp}/alternate lima" INSTANCE_NAME=alternate
export DOCKER_HOST='tcp://unrelated.invalid:2375' DOCKER_CONTEXT=unrelated COMPOSE_REMOVE_ORPHANS=true
unset LAB_POSTGRES_PORT LAB_REDIS_PORT

lab() { bash "${root}/scripts/lab.sh" "$@"; }

assert_compose_args() {
  printf '%s\n' compose --project-name ducker-lab-data --env-file /dev/null \
    -f "${root}/apps/labs/data/compose.yaml" "$@" >"${tmp}/expected"
  diff -u "${tmp}/expected" "${tmp}/args"
}

lab start data >/dev/null
assert_compose_args up --detach --wait --wait-timeout 120
printf '%s\n' 15432 16379 >"${tmp}/expected-ports"
diff -u "${tmp}/expected-ports" "${tmp}/ports"

LAB_POSTGRES_PORT=25432 LAB_REDIS_PORT=26379 lab start >/dev/null
printf '%s\n' 25432 26379 >"${tmp}/expected-ports"
diff -u "${tmp}/expected-ports" "${tmp}/ports"

lab status >/dev/null
assert_compose_args ps --all
lab stop data >/dev/null
assert_compose_args down
lab stop data --volumes >/dev/null
assert_compose_args down --volumes

rm "${tmp}/docker-called"
if lab start unknown >"${tmp}/error" 2>&1 ||
  lab stop --other >"${tmp}/error" 2>&1 ||
  LAB_POSTGRES_PORT=65536 lab start >"${tmp}/error" 2>&1 ||
  LAB_REDIS_PORT=1:6379 lab start >"${tmp}/error" 2>&1 ||
  LAB_REDIS_PORT=15432 lab start >"${tmp}/error" 2>&1 ||
  LAB_TEST_LIMA_STATUS=Stopped lab start >"${tmp}/error" 2>&1 ||
  [[ -e "${tmp}/docker-called" ]]; then
  printf 'A lab command accepted invalid arguments or reached Docker unexpectedly.\n' >&2
  exit 1
fi

printf 'Data lab command routing passed.\n'
