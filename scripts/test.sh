#!/usr/bin/env bash
# Project self-test for docker-lab (safe by default).
#
# Usage:
#   ./scripts/test.sh           # static + make dry-runs (no VM changes)
#   LIVE=1 ./scripts/test.sh    # also verify against a Running Lima VM
#   make test
#   make test LIVE=1
#
# Never runs nuke / vm-uninstall / destructive cleanup.
# shellcheck shell=bash
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/common.sh"

LIVE="${LIVE:-0}"
failures=0
passed=0

pass() {
  printf '  [PASS] %s\n' "$*"
  passed=$((passed + 1))
}
fail() {
  printf '  [FAIL] %s\n' "$*" >&2
  failures=$((failures + 1))
}
skip() { printf '  [SKIP] %s\n' "$*"; }

section() { printf '\n==> %s\n' "$*"; }

assert_cmd() {
  local name="$1"
  shift
  if "$@"; then
    pass "${name}"
  else
    fail "${name}"
  fi
}

# --- Static -----------------------------------------------------------------

section "Static: required files"
REQUIRED_FILES=(
  "${ROOT_DIR}/Makefile"
  "${ROOT_DIR}/Brewfile"
  "${ROOT_DIR}/lima-docker.yaml"
  "${ROOT_DIR}/README.md"
  "${ROOT_DIR}/install.sh"
  "${ROOT_DIR}/config/daemon.json"
  "${ROOT_DIR}/config/zshrc.snippet"
  "${ROOT_DIR}/config/profiles/small.env"
  "${ROOT_DIR}/config/profiles/balanced.env"
  "${ROOT_DIR}/config/profiles/power.env"
  "${ROOT_DIR}/apps/ui/arcane/compose.yaml"
  "${ROOT_DIR}/apps/ui/arcane/.env.example"
  "${ROOT_DIR}/apps/ui/dockhand/compose.yaml"
  "${ROOT_DIR}/apps/ui/dockhand/.env.example"
  "${ROOT_DIR}/scripts/common.sh"
  "${ROOT_DIR}/scripts/install-deps.sh"
  "${ROOT_DIR}/scripts/install-docker-cli-config.sh"
  "${ROOT_DIR}/scripts/install-shell-env.sh"
  "${ROOT_DIR}/scripts/install-lima.sh"
  "${ROOT_DIR}/scripts/install-daemon-config.sh"
  "${ROOT_DIR}/scripts/verify.sh"
  "${ROOT_DIR}/scripts/uninstall.sh"
  "${ROOT_DIR}/scripts/ui.sh"
  "${ROOT_DIR}/scripts/test.sh"
  "${ROOT_DIR}/scripts/doctor.sh"
  "${ROOT_DIR}/scripts/diagnose.sh"
  "${ROOT_DIR}/scripts/stats.sh"
  "${ROOT_DIR}/scripts/benchmark.sh"
  "${ROOT_DIR}/scripts/upgrade.sh"
  "${ROOT_DIR}/scripts/backup.sh"
  "${ROOT_DIR}/scripts/restore.sh"
  "${ROOT_DIR}/scripts/profile.sh"
  "${ROOT_DIR}/docs/installation.md"
  "${ROOT_DIR}/docs/architecture.md"
  "${ROOT_DIR}/docs/troubleshooting.md"
  "${ROOT_DIR}/docs/index.md"
  "${ROOT_DIR}/mkdocs.yml"
  "${ROOT_DIR}/requirements-docs.txt"
  "${ROOT_DIR}/.github/workflows/ci.yml"
  "${ROOT_DIR}/.github/workflows/docs.yml"
  "${ROOT_DIR}/ducker"
)
for f in "${REQUIRED_FILES[@]}"; do
  if [[ -f "${f}" ]]; then
    pass "exists $(basename "$(dirname "${f}")")/$(basename "${f}")"
  else
    fail "missing ${f#"${ROOT_DIR}/"}"
  fi
done

if [[ -f "${ROOT_DIR}/apps/ui/.env" ]]; then
  fail "orphaned apps/ui/.env (should live under apps/ui/<provider>/.env)"
else
  pass "no orphaned apps/ui/.env"
fi

section "Static: ducker CLI"
if [[ -x "${ROOT_DIR}/ducker" ]]; then
  pass "ducker is executable"
else
  fail "ducker missing or not executable"
fi
if bash -n "${ROOT_DIR}/ducker" 2>/dev/null; then
  pass "bash -n ducker"
else
  fail "bash -n ducker"
  bash -n "${ROOT_DIR}/ducker" || true
fi
if "${ROOT_DIR}/ducker" help >/dev/null 2>&1; then
  pass "./ducker help"
else
  fail "./ducker help"
fi

section "Static: bash syntax (bash -n)"
while IFS= read -r -d '' script; do
  if bash -n "${script}" 2>/dev/null; then
    pass "bash -n ${script#"${ROOT_DIR}/"}"
  else
    fail "bash -n ${script#"${ROOT_DIR}/"}"
    bash -n "${script}" || true
  fi
done < <(find "${ROOT_DIR}/scripts" -type f -name '*.sh' -print0 | sort -z)

section "Static: JSON / markers"
assert_cmd "config/daemon.json is valid JSON" \
  python3 -c 'import json,sys; json.load(open(sys.argv[1]))' "${ROOT_DIR}/config/daemon.json"

assert_cmd "zshrc.snippet has begin/end markers" \
  bash -c "grep -qF '${MARKER_BEGIN}' '${ROOT_DIR}/config/zshrc.snippet' && grep -qF '${MARKER_END}' '${ROOT_DIR}/config/zshrc.snippet'"

assert_cmd "Brewfile lists lima + docker" \
  bash -c "grep -q 'lima' '${ROOT_DIR}/Brewfile' && grep -q 'docker' '${ROOT_DIR}/Brewfile'"

assert_cmd "install-deps wires Docker CLI plugins before compose check" \
  bash -c "grep -q 'install-docker-cli-config.sh' '${ROOT_DIR}/scripts/install-deps.sh'"

assert_cmd "config.env has author + version metadata" \
  bash -c "grep -q 'DOCKER_LAB_AUTHOR' '${ROOT_DIR}/config.env' && grep -q 'DOCKER_LAB_VERSION' '${ROOT_DIR}/config.env'"

if "${ROOT_DIR}/ducker" about >/dev/null 2>&1; then
  pass "./ducker about"
else
  fail "./ducker about"
fi

if bash -n "${ROOT_DIR}/install.sh" 2>/dev/null; then
  pass "bash -n install.sh"
else
  fail "bash -n install.sh"
fi

if bash "${ROOT_DIR}/scripts/profile.sh" list >/dev/null 2>&1; then
  pass "scripts/profile.sh list"
else
  fail "scripts/profile.sh list"
fi

if bash "${ROOT_DIR}/scripts/backup.sh" list >/dev/null 2>&1; then
  pass "scripts/backup.sh list"
else
  fail "scripts/backup.sh list"
fi

assert_cmd "README positions Platform Engineering" \
  grep -qi 'Platform Engineering' "${ROOT_DIR}/README.md"

assert_cmd "lima-docker.yaml references debian-13" \
  grep -q 'debian-13' "${ROOT_DIR}/lima-docker.yaml"

assert_cmd "dockhand host port default is 9090" \
  grep -qE 'UI_PORT:-9090|UI_PORT=9090' "${ROOT_DIR}/apps/ui/dockhand/compose.yaml" "${ROOT_DIR}/apps/ui/dockhand/.env.example"

assert_cmd "Makefile does not enable .ONESHELL" \
  bash -c "! grep -q '^\.ONESHELL' '${ROOT_DIR}/Makefile'"

assert_cmd "Makefile has ui firstword collision guard" \
  grep -qF 'ifeq (ui,$(firstword $(MAKECMDGOALS)))' "${ROOT_DIR}/Makefile"

section "Make: help / dry-run / UI collision safety"
cd "${ROOT_DIR}" || exit 1

if make help >/dev/null 2>&1; then
  pass "make help"
else
  fail "make help"
fi

if make -n install >/dev/null 2>&1; then
  pass "make -n install"
else
  fail "make -n install"
fi

# Critical: ui uninstall must NOT invoke lab uninstall.sh instance
dry_ui="$(make -n ui uninstall dockhand 2>&1 || true)"
if printf '%s' "${dry_ui}" | grep -q 'ui\.sh'; then
  pass "make -n ui uninstall dockhand invokes ui.sh"
else
  fail "make -n ui uninstall dockhand did not invoke ui.sh"
  printf '%s\n' "${dry_ui}" >&2
fi
if printf '%s' "${dry_ui}" | grep -q 'uninstall.sh'; then
  # ui path may mention scripts dir; lab collision would pass " instance" as arg
  if printf '%s' "${dry_ui}" | grep -E 'uninstall\.sh[[:space:]]+"?instance"?|[[:space:]]instance$' >/dev/null; then
    fail "make -n ui uninstall dockhand would also run lab vm-uninstall (collision)"
    printf '%s\n' "${dry_ui}" >&2
  else
    pass "make -n ui uninstall dockhand does not run lab vm-uninstall"
  fi
else
  pass "make -n ui uninstall dockhand does not run lab vm-uninstall"
fi

dry_vm="$(make -n vm-uninstall 2>&1 || true)"
if printf '%s' "${dry_vm}" | grep -q 'uninstall.sh' && printf '%s' "${dry_vm}" | grep -q 'instance'; then
  pass "make -n vm-uninstall invokes uninstall.sh instance"
else
  fail "make -n vm-uninstall dry-run unexpected"
  printf '%s\n' "${dry_vm}" >&2
fi

dry_nuke="$(make -n nuke 2>&1 || true)"
if printf '%s' "${dry_nuke}" | grep -q 'uninstall.sh' && printf '%s' "${dry_nuke}" | grep -q 'nuke'; then
  pass "make -n nuke invokes uninstall.sh nuke"
else
  fail "make -n nuke dry-run unexpected"
  printf '%s\n' "${dry_nuke}" >&2
fi

for action in help list; do
  if make -n ui "${action}" >/dev/null 2>&1; then
    pass "make -n ui ${action}"
  else
    fail "make -n ui ${action}"
  fi
done

# ui.sh help works without Docker/Lima
if bash "${ROOT_DIR}/scripts/ui.sh" help >/dev/null 2>&1; then
  pass "scripts/ui.sh help"
else
  fail "scripts/ui.sh help"
fi

section "Lima template validate (if limactl present)"
if command -v limactl >/dev/null 2>&1; then
  if limactl template validate "${ROOT_DIR}/lima-docker.yaml" >/dev/null 2>&1; then
    pass "limactl template validate lima-docker.yaml"
  else
    fail "limactl template validate lima-docker.yaml"
    limactl template validate "${ROOT_DIR}/lima-docker.yaml" || true
  fi
else
  skip "limactl not installed"
fi

section "Host platform hints"
if [[ "$(uname -s)" == "Darwin" && "$(uname -m)" == "arm64" ]]; then
  pass "Darwin arm64 host"
else
  skip "non Apple Silicon host ($(uname -s)/$(uname -m)) — install scripts will refuse"
fi

# --- Live (optional) --------------------------------------------------------

section "Live checks (LIVE=${LIVE})"
if [[ "${LIVE}" != "1" ]]; then
  skip "set LIVE=1 to test against a Running Lima VM"
else
  if ! command -v limactl >/dev/null 2>&1; then
    fail "LIVE=1 but limactl missing"
  elif ! lima_running; then
    fail "LIVE=1 but instance '${INSTANCE_NAME}' is not Running (make install / make start)"
  else
    pass "instance ${INSTANCE_NAME} is Running"

    export DOCKER_HOST="unix://${HOME}/.lima/${INSTANCE_NAME}/sock/docker.sock"
    unset DOCKER_CONTEXT || true

    if bash "${ROOT_DIR}/scripts/verify.sh"; then
      pass "scripts/verify.sh"
    else
      fail "scripts/verify.sh"
    fi

    if make -C "${ROOT_DIR}" status >/dev/null 2>&1; then
      pass "make status"
    else
      fail "make status"
    fi

    if make -C "${ROOT_DIR}" ui list >/dev/null 2>&1; then
      pass "make ui list"
    else
      fail "make ui list"
    fi

    if docker run --rm hello-world >/dev/null 2>&1; then
      pass "docker run hello-world"
    else
      fail "docker run hello-world"
    fi
  fi
fi

# --- Summary ----------------------------------------------------------------

printf '\n==> Results: %d passed, %d failed\n' "${passed}" "${failures}"
if [[ "${failures}" -ne 0 ]]; then
  die "${failures} test(s) failed"
fi
log "All tests passed"
if [[ "${LIVE}" != "1" ]]; then
  log "Tip: run LIVE=1 make test after \`make install\` for full runtime validation"
fi
