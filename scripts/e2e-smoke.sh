#!/usr/bin/env bash
# End-to-end smoke of EVERY ducker command on this Mac.
# Logs a results table. Destructive nuke runs last, then reinstall restores the lab.
# shellcheck shell=bash
set -uo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DUCKER="${ROOT}/ducker"
LOG="${ROOT}/.e2e-results.log"
: > "${LOG}"

export ROOT_DIR="${ROOT}"
export DOCKER_HOST="unix://${HOME}/.lima/docker/sock/docker.sock"
export DOCKER_CONTEXT=

pass=0
fail=0
skip=0

record() {
  local name="$1" code="$2" note="${3:-}"
  local status
  if [[ "${code}" == "skip" ]]; then
    status="SKIP"
    skip=$((skip + 1))
  elif [[ "${code}" -eq 0 ]]; then
    status="PASS"
    pass=$((pass + 1))
  else
    status="FAIL"
    fail=$((fail + 1))
  fi
  printf '| %s | %s | %s | %s |\n' "${name}" "${code}" "${status}" "${note}" | tee -a "${LOG}"
}

run() {
  local name="$1"
  shift
  local out ec
  printf '\n========== %s ==========\n' "${name}" | tee -a "${LOG}"
  set +e
  out="$("$@" 2>&1)"
  ec=$?
  set +e
  printf '%s\n' "${out}" | tee -a "${LOG}" | tail -n 40
  record "${name}" "${ec}" "$(printf '%s' "${out}" | tr '\n' ' ' | cut -c1-120)"
  return 0
}

run_expect() {
  # run but ignore listed exit codes as success (e.g. open browser quirks)
  local name="$1"
  local ok_codes="$2"
  shift 2
  local out ec
  printf '\n========== %s ==========\n' "${name}" | tee -a "${LOG}"
  set +e
  out="$("$@" 2>&1)"
  ec=$?
  set +e
  printf '%s\n' "${out}" | tee -a "${LOG}" | tail -n 40
  if [[ " ${ok_codes} " == *" ${ec} "* ]]; then
    record "${name}" 0 "exit=${ec} accepted: $(printf '%s' "${out}" | tr '\n' ' ' | cut -c1-100)"
  else
    record "${name}" "${ec}" "$(printf '%s' "${out}" | tr '\n' ' ' | cut -c1-120)"
  fi
}

echo "# ducker e2e $(date '+%Y-%m-%dT%H:%M:%S%z')" | tee -a "${LOG}"
echo "| Command | Exit | Status | Notes |" | tee -a "${LOG}"
echo "| --- | --- | --- | --- |" | tee -a "${LOG}"

cd "${ROOT}" || exit 1

# --- Meta -------------------------------------------------------------------
run "ducker help" "${DUCKER}" help
run "ducker about" "${DUCKER}" about
run "ducker version" "${DUCKER}" version

# --- CLI symlink cycle (restore link) ---------------------------------------
run "ducker cli-uninstall" "${DUCKER}" cli-uninstall
run "ducker cli-install" "${DUCKER}" cli-install auto

# --- Full install -----------------------------------------------------------
run "ducker install" "${DUCKER}" install

# --- Install pieces (idempotent re-run) -------------------------------------
run "ducker deps" "${DUCKER}" deps
run "ducker config" "${DUCKER}" config
run "ducker lima" "${DUCKER}" lima
run "ducker daemon" "${DUCKER}" daemon
run "ducker verify" "${DUCKER}" verify
run "ducker doctor" "${DUCKER}" doctor

# --- Lifecycle --------------------------------------------------------------
run "ducker status" "${DUCKER}" status
run "ducker list" "${DUCKER}" list
run "ducker stop" "${DUCKER}" stop
run "ducker start" "${DUCKER}" start
run "ducker restart" "${DUCKER}" restart
run "ducker status (after restart)" "${DUCKER}" status

# Non-interactive guest shell (interactive `ducker shell` cannot be automated)
run "limactl shell docker -- uname -a" limactl shell docker -- uname -a

run "ducker sync-home-template" "${DUCKER}" sync-home-template
run "ducker clean" "${DUCKER}" clean
run "ducker start (after clean)" "${DUCKER}" start

# --- Runtime smoke ----------------------------------------------------------
run "ducker test-run" "${DUCKER}" test-run
run "LIVE=1 ducker test" env LIVE=1 "${DUCKER}" test
run "docker hello-world" docker run --rm hello-world

# --- UI: arcane -------------------------------------------------------------
run "ducker ui help" "${DUCKER}" ui help
run "ducker ui list" "${DUCKER}" ui list
run "ducker ui install arcane" "${DUCKER}" ui install arcane
run "ducker ui status arcane" "${DUCKER}" ui status arcane
run_expect "ducker ui open arcane" "0 1" "${DUCKER}" ui open arcane
run "ducker ui stop arcane" "${DUCKER}" ui stop arcane
run "ducker ui start arcane" "${DUCKER}" ui start arcane
run "ducker ui down arcane" "${DUCKER}" ui down arcane
run "ducker ui up arcane" "${DUCKER}" ui up arcane

# --- UI: dockhand -----------------------------------------------------------
run "ducker ui install dockhand" "${DUCKER}" ui install dockhand
run "ducker ui default dockhand" "${DUCKER}" ui default dockhand
run "ducker ui status dockhand" "${DUCKER}" ui status dockhand
run "ducker ui default arcane" "${DUCKER}" ui default arcane
run "ducker ui uninstall dockhand" "${DUCKER}" ui uninstall dockhand
run "ducker ui uninstall arcane" "${DUCKER}" ui uninstall arcane
run "ducker ui list (after uninstall)" "${DUCKER}" ui list

run "ducker test (static)" "${DUCKER}" test

# --- Soft cleanup: VM only, then reinstall ----------------------------------
run "ducker vm-uninstall" "${DUCKER}" vm-uninstall
run "ducker install (after vm-uninstall)" "${DUCKER}" install

# --- uninstall alias (same as vm-uninstall) ---------------------------------
run "ducker uninstall" "${DUCKER}" uninstall
run "ducker install (after uninstall)" "${DUCKER}" install

# --- lab-uninstall / uninstall-host ----------------------------------------
run "ducker lab-uninstall" "${DUCKER}" lab-uninstall
run "ducker install (after lab-uninstall)" "${DUCKER}" install
run "ducker uninstall-host" "${DUCKER}" uninstall-host
run "ducker install (after uninstall-host)" "${DUCKER}" install

# --- purge + nuke (full wipe) then final restore ---------------------------
run "CONFIRM=yes ducker purge" env CONFIRM=yes "${DUCKER}" purge
run "ducker install (after purge)" "${DUCKER}" install
run "CONFIRM=yes ducker nuke" env CONFIRM=yes "${DUCKER}" nuke
run "ducker install (FINAL restore)" "${DUCKER}" install
run "ducker verify (FINAL)" "${DUCKER}" verify
run "ducker status (FINAL)" "${DUCKER}" status
run "ducker about (FINAL)" "${DUCKER}" about

printf '\n==> E2E complete: %d PASS, %d FAIL, %d SKIP\n' "${pass}" "${fail}" "${skip}" | tee -a "${LOG}"
printf 'Full log: %s\n' "${LOG}"
[[ "${fail}" -eq 0 ]]
