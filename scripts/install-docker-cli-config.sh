#!/usr/bin/env bash
# Merge Homebrew cliPluginsExtraDirs into ~/.docker/config.json (idempotent).
# shellcheck shell=bash
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/common.sh"

require_cmd python3
mkdir -p "$(dirname "${DOCKER_CONFIG_JSON}")"

log "Ensuring Docker CLI can find Homebrew plugins (${CLI_PLUGINS_DIR})"
python3 - "${DOCKER_CONFIG_JSON}" "${CLI_PLUGINS_DIR}" << 'PY'
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

path.write_text(json.dumps(cfg, indent="\t") + "\n")
print(f"wrote {path}")
PY

log "Docker CLI config ready: ${DOCKER_CONFIG_JSON}"
