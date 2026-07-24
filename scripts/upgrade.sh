#!/usr/bin/env bash
# Safely upgrade host brew packages and re-apply lab configuration.
# shellcheck shell=bash
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/common.sh"

require_macos_arm
ensure_brew
require_file "${ROOT_DIR}/Brewfile"

log "Upgrading Homebrew packages from Brewfile"
brew update
brew bundle --file="${ROOT_DIR}/Brewfile"
# Upgrade formulae named in Brewfile when already installed
while read -r line; do
  case "${line}" in
    brew\ *)
      pkg="${line#brew }"
      pkg="${pkg//\"/}"
      pkg="${pkg//\'/}"
      brew upgrade "${pkg}" 2> /dev/null || true
      ;;
  esac
done < "${ROOT_DIR}/Brewfile"

log "Re-applying host Docker CLI + shell config"
bash "${ROOT_DIR}/scripts/install-docker-cli-config.sh"
bash "${ROOT_DIR}/scripts/install-shell-env.sh"

if lima_running; then
  log "Re-applying guest daemon.json"
  bash "${ROOT_DIR}/scripts/install-daemon-config.sh"
  log "Verifying"
  bash "${ROOT_DIR}/scripts/verify.sh"
else
  warn "Lima instance not Running — skipped daemon re-apply and verify"
  warn "Start with: ducker start && ducker daemon && ducker verify"
fi

log "Upgrade finished"
