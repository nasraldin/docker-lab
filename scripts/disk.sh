#!/usr/bin/env bash
# Report storage, preview BuildKit cleanup, or monitor Lima's host filesystem.
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/common.sh"

export PATH="/opt/homebrew/bin:/usr/bin:/bin:/usr/sbin:/sbin:${PATH}"
label="org.docker-lab.disk-monitor"
domain="gui/$(id -u)"
agent_dir="$HOME/Library/LaunchAgents"
plist="$agent_dir/$label.plist"
log_dir="$HOME/Library/Logs/Docker Lab"
monitor_log="$log_dir/disk-monitor.log"
monitor_state="$log_dir/.disk-monitor-low"
disk_path="$LIMA_HOME"
[[ -d "$disk_path" ]] || disk_path="$HOME"

usage() {
  cat <<'HELP'
Usage: ducker disk [report]
       ducker disk prune [--older-than DURATION] [--apply]
       ducker disk monitor enable [MIN_FREE_GIB]
       ducker disk monitor status|disable
The cleanup preview defaults to unused BuildKit cache last used over 168h ago.
HELP
}

report() {
  local file
  log "macOS filesystem backing Lima"
  df -h "$disk_path"
  for file in "$LIMA_HOME/$INSTANCE_NAME"/{disk,diffdisk}; do
    if [[ -f "$file" ]]; then
      log "Allocation of $INSTANCE_NAME's virtual disk on macOS"
      du -h "$file"
    fi
  done
  if ! lima_running; then
    log "Lima instance '$INSTANCE_NAME' is stopped or unavailable"
    return
  fi
  log "Guest root filesystem ($INSTANCE_NAME)"
  limactl shell "$INSTANCE_NAME" -- df -h / || warn "Guest filesystem unavailable"
  log "Docker disk usage and reclaimable space"
  on_lima_docker system df || warn "Docker usage unavailable on '$INSTANCE_NAME'"
}

on_lima_docker() {
  env -u DOCKER_HOST -u DOCKER_CONTEXT docker --host "$(lima_docker_host)" "$@"
}

preview_build_cache() {
  local socket cache
  require_cmd curl python3
  socket="$(lima_docker_host)"
  # Buildx du rounds last-use times and drops the until cutoff. The versioned
  # Engine endpoint returns complete cache records from the same daemon.
  cache="$(curl --disable --fail --silent --show-error --noproxy '*' \
    --unix-socket "${socket#unix://}" 'http://localhost/v1.44/system/df?type=build-cache')" ||
    die "Could not read build cache for '$INSTANCE_NAME'"
  python3 -c '
import json
import re
import sys
from datetime import datetime, timedelta, timezone

duration = sys.argv[1]
seconds = int(duration[:-1]) * {"h": 3600, "m": 60, "s": 1}[duration[-1]]
if seconds > 9_223_372_036:
    sys.exit("Cache age is too large.")
cutoff = datetime.now(timezone.utc) - timedelta(seconds=seconds)

print("ID\tSIZE (BYTES)\tLAST USED")
for record in json.load(sys.stdin)["BuildCache"] or []:
    if record["InUse"] or record["Shared"] or record["Type"] in {"internal", "frontend"}:
        continue
    last_used = record["LastUsedAt"]
    if last_used is not None:
        # Docker can return nanoseconds. Older macOS Python accepts six decimal places.
        timestamp = re.sub(r"\.(\d+)", lambda match: "." + match[1][:6].ljust(6, "0"), last_used)
        if datetime.fromisoformat(timestamp.replace("Z", "+00:00")) > cutoff:
            continue
    print("{}\t{}\t{}".format(record["ID"], record["Size"], last_used or "never"))
  ' "$1" <<<"$cache"
}

prune() {
  local older_than=168h apply=false
  while (($#)); do
    case "$1" in
      --older-than)
        [[ $# -ge 2 && "$2" =~ ^[1-9][0-9]{0,9}[hms]$ ]] || die "Use a duration such as 24h or 30m"
        older_than="$2"
        shift
        ;;
      --apply) apply=true ;;
      *) die "Unknown disk prune option '$1'" ;;
    esac
    shift
  done
  lima_running || die "Start Lima instance '$INSTANCE_NAME' first"
  log "Unused BuildKit cache for '$INSTANCE_NAME', last used over $older_than ago"
  preview_build_cache "$older_than"
  if [[ "$apply" == true ]]; then
    on_lima_docker buildx prune --builder default --filter "until=$older_than" --force
    limactl shell "$INSTANCE_NAME" -- sudo systemctl start fstrim.service
  else
    log "Preview only. Repeat with --apply to remove matching build cache and trim the guest disk."
  fi
}

check_host_space() {
  local threshold="$1" available
  available="$(df -Pk "$disk_path" | awk 'NR == 2 {print $4}')"
  [[ "$available" =~ ^[0-9]+$ ]] || die "Could not read free space for '$disk_path'"
  if ((available < threshold * 1024 * 1024)); then
    if [[ ! -e "$monitor_state" ]]; then
      local message="Lima storage has $((available / 1024 / 1024)) GiB free. Alert threshold is $threshold GiB."
      printf '%s %s\n' "$(date '+%Y-%m-%d %H:%M:%S %z')" "$message"
      touch "$monitor_state"
      osascript - "$message" >/dev/null 2>&1 <<'APPLESCRIPT' || true
on run argv
  display notification (item 1 of argv) with title "Docker Lab"
end run
APPLESCRIPT
    fi
  elif [[ -e "$monitor_state" ]]; then
    printf '%s Free space recovered above %s GiB.\n' "$(date '+%Y-%m-%d %H:%M:%S %z')" "$threshold"
    rm -f -- "$monitor_state"
  fi
}

monitor() {
  local threshold="${2:-50}" candidate
  case "${1:-status}" in
    enable)
      [[ $# -le 2 && "$threshold" =~ ^[1-9][0-9]{0,5}$ ]] || die "Set a positive threshold in GiB"
      require_macos_arm
      require_cmd jq launchctl plutil
      umask 077
      mkdir -p "$agent_dir" "$log_dir"
      candidate="$(mktemp "$agent_dir/.$label.XXXXXXXX")"
      if ! jq -n --arg label "$label" --arg script "$ROOT_DIR/scripts/disk.sh" \
        --arg home "$HOME" --arg lima_home "$LIMA_HOME" --arg threshold "$threshold" --arg log "$monitor_log" '
          {Label:$label, ProgramArguments:["/bin/bash",$script,"monitor","check",$threshold],
           EnvironmentVariables:{HOME:$home, LIMA_HOME:$lima_home}, RunAtLoad:true, StartInterval:300,
           StandardOutPath:$log, StandardErrorPath:$log}
        ' | plutil -convert xml1 -o "$candidate" -- -; then
        rm -f -- "$candidate"
        die "Could not create disk monitor LaunchAgent"
      fi
      if launchctl print "$domain/$label" >/dev/null 2>&1; then
        launchctl bootout "$domain/$label"
      fi
      mv -f -- "$candidate" "$plist"
      launchctl bootstrap "$domain" "$plist"
      log "Disk monitor enabled at $threshold GiB. Log: $monitor_log"
      ;;
    disable)
      [[ $# -eq 1 ]] || die "Usage: ducker disk monitor disable"
      if launchctl print "$domain/$label" >/dev/null 2>&1; then
        launchctl bootout "$domain/$label"
      fi
      rm -f -- "$plist" "$monitor_state"
      log "Disk monitor disabled"
      ;;
    status)
      [[ $# -le 1 ]] || die "Usage: ducker disk monitor status"
      if launchctl print "$domain/$label" >/dev/null 2>&1; then
        log "Disk monitor enabled. Log: $monitor_log"
      else
        log "Disk monitor inactive"
      fi
      ;;
    check)
      [[ $# -eq 2 && "$threshold" =~ ^[1-9][0-9]{0,5}$ ]] || die "Invalid monitor threshold"
      check_host_space "$threshold"
      ;;
    *) die "Unknown disk monitor action '$1'" ;;
  esac
}

case "${1:-report}" in
  report)
    [[ $# -le 1 ]] || die "Usage: ducker disk report"
    report
    ;;
  prune)
    shift
    prune "$@"
    ;;
  monitor)
    shift
    monitor "$@"
    ;;
  -h | --help | help) usage ;;
  *)
    usage
    exit 1
    ;;
esac
