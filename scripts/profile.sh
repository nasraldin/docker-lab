#!/usr/bin/env bash
# Apply or list VM resource profiles (small | balanced | power).
# shellcheck shell=bash
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/common.sh"

PROFILES_DIR="${ROOT_DIR}/config/profiles"
ACTIVE_FILE="${ROOT_DIR}/config/profiles/.active"

usage() {
  cat << 'EOF'
Usage:
  ducker profile list
  ducker profile show
  ducker profile <small|balanced|power>

Applies cpus/memory/disk to lima-docker.yaml and records the active profile.
Changing size after the VM exists usually requires: ducker vm-uninstall && ducker lima
EOF
}

list_profiles() {
  local f name
  printf '%-10s %-6s %-8s %-8s %s\n' "NAME" "CPUS" "MEMORY" "DISK" "DESCRIPTION"
  printf '%-10s %-6s %-8s %-8s %s\n' "----" "----" "------" "----" "-----------"
  for f in "${PROFILES_DIR}"/*.env; do
    [[ -f "${f}" ]] || continue
    # shellcheck source=/dev/null
    source "${f}"
    name="$(basename "${f}" .env)"
    printf '%-10s %-6s %-8s %-8s %s\n' \
      "${name}" "${PROFILE_CPUS}" "${PROFILE_MEMORY}" "${PROFILE_DISK}" \
      "${PROFILE_DESCRIPTION:-}"
  done
  if [[ -f "${ACTIVE_FILE}" ]]; then
    printf '\nActive: %s\n' "$(tr -d '[:space:]' < "${ACTIVE_FILE}")"
  else
    printf '\nActive: (none — lima-docker.yaml defaults / power-class)\n'
  fi
}

show_active() {
  if [[ -f "${ACTIVE_FILE}" ]]; then
    local name
    name="$(tr -d '[:space:]' < "${ACTIVE_FILE}")"
    require_file "${PROFILES_DIR}/${name}.env"
    # shellcheck source=/dev/null
    source "${PROFILES_DIR}/${name}.env"
    cat << EOF
Active profile: ${name}
  CPUs:    ${PROFILE_CPUS}
  Memory:  ${PROFILE_MEMORY}
  Disk:    ${PROFILE_DISK}
  Notes:   ${PROFILE_DESCRIPTION:-}
  Template:${LIMA_TEMPLATE}
EOF
  else
    log "No active profile file — showing lima-docker.yaml values"
    awk '/^(cpus|memory|disk):/ {print}' "${LIMA_TEMPLATE}"
  fi
}

apply_profile() {
  local name="$1"
  local env_file="${PROFILES_DIR}/${name}.env"
  require_file "${env_file}" "${LIMA_TEMPLATE}"

  # shellcheck source=/dev/null
  source "${env_file}"

  log "Applying profile '${name}' → ${LIMA_TEMPLATE}"
  # Portable in-place edit for cpus / memory / disk top-level keys
  awk -v cpus="${PROFILE_CPUS}" -v mem="${PROFILE_MEMORY}" -v disk="${PROFILE_DISK}" '
    BEGIN { done_c=0; done_m=0; done_d=0 }
    /^cpus:/   && !done_c { print "cpus: " cpus; done_c=1; next }
    /^memory:/ && !done_m { print "memory: " mem; done_m=1; next }
    /^disk:/   && !done_d { print "disk: " disk; done_d=1; next }
    { print }
  ' "${LIMA_TEMPLATE}" > "${LIMA_TEMPLATE}.tmp"
  mv "${LIMA_TEMPLATE}.tmp" "${LIMA_TEMPLATE}"

  printf '%s\n' "${name}" > "${ACTIVE_FILE}"
  log "Active profile set to '${name}'"
  if lima_exists; then
    warn "Instance '${INSTANCE_NAME}' already exists — CPU/memory/disk changes need recreate:"
    warn "  ducker backup && ducker vm-uninstall && ducker lima && ducker daemon && ducker verify"
  else
    log "No instance yet — next: ducker install  (or ducker lima)"
  fi
}

CMD="${1:-list}"
case "${CMD}" in
  -h | --help | help) usage ;;
  list | ls) list_profiles ;;
  show | status) show_active ;;
  small | balanced | power) apply_profile "${CMD}" ;;
  *)
    die "Unknown profile '${CMD}'. Use: small | balanced | power | list | show"
    ;;
esac
