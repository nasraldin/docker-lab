#!/usr/bin/env bash
# Install managed DOCKER_HOST block into ~/.zshrc (idempotent).
# shellcheck shell=bash
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/common.sh"

require_file "${ROOT_DIR}/config/zshrc.snippet"
require_cmd python3

mkdir -p "$(dirname "${ZSHRC_FILE}")"
[[ -f "${ZSHRC_FILE}" ]] || touch "${ZSHRC_FILE}"

log "Installing managed shell block into ${ZSHRC_FILE}"
python3 - "${ZSHRC_FILE}" "${ROOT_DIR}/config/zshrc.snippet" "${MARKER_BEGIN}" "${MARKER_END}" <<'PY'
import pathlib
import re
import sys

zshrc = pathlib.Path(sys.argv[1])
snippet = pathlib.Path(sys.argv[2]).read_text()
begin, end = sys.argv[3], sys.argv[4]
text = zshrc.read_text() if zshrc.exists() else ""

# Remove prior managed block
pattern = re.compile(
    re.escape(begin) + r".*?" + re.escape(end) + r"\n?",
    flags=re.DOTALL,
)
text = pattern.sub("", text)

# Remove older hand-edited Lima DOCKER_HOST lines (best-effort, non-destructive to unrelated config)
legacy = re.compile(
    r"(?m)^# Lima is the only Docker daemon.*\n"
    r"(?:#.*\n)*"
    r"export DOCKER_HOST=unix://\$\{HOME\}/\.lima/docker/sock/docker\.sock\n"
    r"unset DOCKER_CONTEXT\n?"
)
text = legacy.sub("", text)

if not text.endswith("\n") and text:
    text += "\n"
text += snippet if snippet.endswith("\n") else snippet + "\n"
zshrc.write_text(text)
print(f"updated {zshrc}")
PY

log "Shell env ready (open a new terminal or: source ${ZSHRC_FILE})"
