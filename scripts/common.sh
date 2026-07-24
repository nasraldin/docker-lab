#!/usr/bin/env bash
# Shared helpers for docker-lab Make targets.
# shellcheck shell=bash

set -euo pipefail

ROOT_DIR="${ROOT_DIR:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
export ROOT_DIR

INSTANCE_NAME="${INSTANCE_NAME:-docker}"
LIMA_TEMPLATE="${LIMA_TEMPLATE:-${ROOT_DIR}/lima-docker.yaml}"
DOCKER_CONFIG_JSON="${DOCKER_CONFIG_JSON:-${HOME}/.docker/config.json}"
ZSHRC_FILE="${ZSHRC_FILE:-${HOME}/.zshrc}"
MARKER_BEGIN='# >>> lima-docker-homelab >>>'
MARKER_END='# <<< lima-docker-homelab <<<'
export MARKER_BEGIN MARKER_END

# Homebrew Docker CLI plugins (Apple Silicon or Intel)
_default_cli_plugins_dir() {
  local prefix=""
  if [[ -x /opt/homebrew/bin/brew ]]; then
    prefix="$(/opt/homebrew/bin/brew --prefix 2> /dev/null || true)"
  elif [[ -x /usr/local/bin/brew ]]; then
    prefix="$(/usr/local/bin/brew --prefix 2> /dev/null || true)"
  elif command -v brew > /dev/null 2>&1; then
    prefix="$(brew --prefix 2> /dev/null || true)"
  fi
  if [[ -n "${prefix}" ]]; then
    printf '%s/lib/docker/cli-plugins' "${prefix}"
  else
    printf '%s' "/opt/homebrew/lib/docker/cli-plugins"
  fi
}
CLI_PLUGINS_DIR="${CLI_PLUGINS_DIR:-$(_default_cli_plugins_dir)}"

log() { printf '==> %s\n' "$*"; }
warn() { printf 'WARN: %s\n' "$*" >&2; }
die() {
  printf 'ERROR: %s\n' "$*" >&2
  exit 1
}

require_cmd() {
  local cmd
  for cmd in "$@"; do
    command -v "${cmd}" > /dev/null 2>&1 || die "Missing required command: ${cmd}"
  done
}

require_macos_arm() {
  [[ "$(uname -s)" == "Darwin" ]] || die "This stack targets macOS only"
  local arch
  arch="$(uname -m)"
  [[ "${arch}" == "arm64" ]] || die "Expected Apple Silicon (arm64); found ${arch}"
}

require_file() {
  local path
  for path in "$@"; do
    [[ -f "${path}" ]] || die "Required file not found: ${path}"
  done
}

lima_status() {
  limactl list -q 2> /dev/null | grep -qx "${INSTANCE_NAME}" || return 1
  limactl list -f '{{.Name}} {{.Status}}' 2> /dev/null |
    awk -v n="${INSTANCE_NAME}" '$1 == n { print $2; exit }'
}

lima_exists() {
  limactl list -q 2> /dev/null | grep -qx "${INSTANCE_NAME}"
}

lima_running() {
  [[ "$(lima_status 2> /dev/null || true)" == "Running" ]]
}

ensure_brew() {
  require_cmd brew
  # Prefer Homebrew's ARM prefix on Apple Silicon
  if [[ -x /opt/homebrew/bin/brew ]]; then
    eval "$(/opt/homebrew/bin/brew shellenv)"
  fi
}
