#!/usr/bin/env bash
# Restore lab configuration from a backup created by backup.sh
# shellcheck shell=bash
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BACKUP_MODE=restore exec bash "${ROOT}/backup.sh" "$@"
