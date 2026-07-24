#!/usr/bin/env bash
# Install host Homebrew packages (idempotent via brew bundle).
# shellcheck shell=bash
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/common.sh"

require_macos_arm
ensure_brew
require_file "${ROOT_DIR}/Brewfile"

log "Installing Homebrew dependencies from Brewfile"
brew bundle --file="${ROOT_DIR}/Brewfile"

# Homebrew ships compose/buildx as Docker CLI plugins under lib/docker/cli-plugins.
# Wire that path into ~/.docker/config.json before we call `docker compose`.
bash "${ROOT_DIR}/scripts/install-docker-cli-config.sh"

log "Verifying binaries"
require_cmd limactl docker yq jq

if [[ ! -d "${CLI_PLUGINS_DIR}" ]]; then
  die "Docker CLI plugins dir missing: ${CLI_PLUGINS_DIR}"
fi
if [[ ! -e "${CLI_PLUGINS_DIR}/docker-compose" && ! -e "${CLI_PLUGINS_DIR}/compose" ]]; then
  die "docker-compose plugin not installed under ${CLI_PLUGINS_DIR}"
fi
if [[ ! -e "${CLI_PLUGINS_DIR}/docker-buildx" && ! -e "${CLI_PLUGINS_DIR}/buildx" ]]; then
  die "docker-buildx plugin not installed under ${CLI_PLUGINS_DIR}"
fi

if ! docker compose version > /dev/null 2>&1; then
  die "docker compose still unavailable after wiring cliPluginsExtraDirs (${CLI_PLUGINS_DIR}). Check ${DOCKER_CONFIG_JSON}"
fi
if ! docker buildx version > /dev/null 2>&1; then
  die "docker buildx still unavailable after wiring cliPluginsExtraDirs (${CLI_PLUGINS_DIR}). Check ${DOCKER_CONFIG_JSON}"
fi

log "Host tools ready"
limactl --version
docker --version
docker compose version
docker buildx version
