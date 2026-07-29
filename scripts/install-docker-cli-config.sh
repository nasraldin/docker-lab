#!/usr/bin/env bash
# Merge Homebrew cliPluginsExtraDirs + host credential store into ~/.docker/config.json.
# Also strip Docker Desktop leftovers (broken plugin symlinks, desktop credsStore).
# shellcheck shell=bash
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/common.sh"

require_cmd python3
mkdir -p "$(dirname "${DOCKER_CONFIG_JSON}")"

clean_desktop_cli_plugin_symlinks() {
  local plugins_dir="${HOME}/.docker/cli-plugins"
  [[ -d "${plugins_dir}" ]] || return 0

  local entry target
  shopt -s nullglob
  for entry in "${plugins_dir}"/*; do
    [[ -L "${entry}" ]] || continue
    target="$(readlink "${entry}" 2>/dev/null || true)"
    if [[ "${target}" == *"/Docker.app/"* ]] || [[ ! -e "${entry}" ]]; then
      rm -f "${entry}"
      log "Removed Docker Desktop CLI plugin symlink: $(basename "${entry}")"
    fi
  done
  shopt -u nullglob

  if [[ -d "${plugins_dir}" ]] && [[ -z "$(ls -A "${plugins_dir}" 2>/dev/null || true)" ]]; then
    rmdir "${plugins_dir}" 2>/dev/null || true
  fi
}

log "Cleaning Docker Desktop CLI plugin symlinks (if any)"
clean_desktop_cli_plugin_symlinks

log "Ensuring Docker CLI can find Homebrew plugins (${CLI_PLUGINS_DIR})"
python3 - "${DOCKER_CONFIG_JSON}" "${CLI_PLUGINS_DIR}" <<'PY'
import json
import sys
from pathlib import Path

path = Path(sys.argv[1])
plugin_dir = sys.argv[2]

cfg = {}
if path.exists() and path.stat().st_size > 0:
    cfg = json.loads(path.read_text())
    if not isinstance(cfg, dict):
        raise SystemExit(f"{path} must contain a JSON object")

dirs = cfg.get("cliPluginsExtraDirs")
if dirs is None:
    dirs = []
if not isinstance(dirs, list):
    raise SystemExit("cliPluginsExtraDirs must be a list")

if plugin_dir not in dirs:
    dirs.append(plugin_dir)

cfg["cliPluginsExtraDirs"] = dirs
# Lima-only: prefer DOCKER_HOST over a sticky non-default context
cfg.pop("currentContext", None)

# Docker Desktop uses credsStore=desktop; Lima lab needs osxkeychain + brew helper.
creds = cfg.get("credsStore")
if creds in (None, "", "desktop"):
    cfg["credsStore"] = "osxkeychain"

# Drop Desktop-only CLI plugin hook config (ai/scout/debug/etc.).
plugins = cfg.get("plugins")
if isinstance(plugins, dict):
    desktop_keys = {"ai", "scout", "debug", "compose", "desktop", "extension", "-x-cli-hints"}
    if desktop_keys.intersection(plugins.keys()):
        cfg.pop("plugins", None)

# Desktop feature flags are not used without Desktop.
cfg.pop("features", None)

path.write_text(json.dumps(cfg, indent="\t") + "\n")
print(f"wrote {path}")
PY

log "Docker CLI config ready: ${DOCKER_CONFIG_JSON}"
