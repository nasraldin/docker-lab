#!/usr/bin/env bash
# install.sh — bootstrap Docker Lab + ducker CLI on Apple Silicon macOS
#
#   curl -fsSL https://raw.githubusercontent.com/nasraldin/docker-lab/main/install.sh | bash
#
# Env overrides:
#   DOCKER_LAB_DIR   install/clone path (default: ~/homelab/docker-lab)
#   DOCKER_LAB_REF   git ref to checkout (default: main)
#   SKIP_INSTALL=1   only clone + cli-install (skip ducker install)
# shellcheck shell=bash
set -euo pipefail

REPO_URL="${REPO_URL:-https://github.com/nasraldin/docker-lab.git}"
DOCKER_LAB_DIR="${DOCKER_LAB_DIR:-${HOME}/homelab/docker-lab}"
DOCKER_LAB_REF="${DOCKER_LAB_REF:-main}"
SKIP_INSTALL="${SKIP_INSTALL:-0}"

log() { printf '==> %s\n' "$*"; }
die() {
  printf 'ERROR: %s\n' "$*" >&2
  exit 1
}

[[ "$(uname -s)" == "Darwin" ]] || die "Docker Lab targets macOS only"
[[ "$(uname -m)" == "arm64" ]] || die "Apple Silicon (arm64) required; found $(uname -m)"
command -v brew >/dev/null 2>&1 || die "Homebrew is required — install from https://brew.sh"
command -v git >/dev/null 2>&1 || die "git is required"

if [[ -x /opt/homebrew/bin/brew ]]; then
  # shellcheck disable=SC1091
  eval "$(/opt/homebrew/bin/brew shellenv)"
fi

if [[ -d "${DOCKER_LAB_DIR}/.git" ]]; then
  log "Updating existing clone at ${DOCKER_LAB_DIR}"
  git -C "${DOCKER_LAB_DIR}" fetch --tags origin
  git -C "${DOCKER_LAB_DIR}" checkout "${DOCKER_LAB_REF}"
  git -C "${DOCKER_LAB_DIR}" pull --ff-only origin "${DOCKER_LAB_REF}" || true
else
  log "Cloning ${REPO_URL} → ${DOCKER_LAB_DIR}"
  mkdir -p "$(dirname "${DOCKER_LAB_DIR}")"
  git clone --branch "${DOCKER_LAB_REF}" "${REPO_URL}" "${DOCKER_LAB_DIR}"
fi

chmod +x "${DOCKER_LAB_DIR}/ducker"
log "Installing global ducker CLI"
"${DOCKER_LAB_DIR}/ducker" cli-install

if [[ "${SKIP_INSTALL}" == "1" ]]; then
  log "SKIP_INSTALL=1 — done. Run: ducker install"
  exit 0
fi

log "Running ducker install (deps + Lima + Docker)"
"${DOCKER_LAB_DIR}/ducker" install

log "Done. Try: ducker about && ducker status"
