# Run and maintain your lab

## Disk space and alerts

Run `ducker disk` for macOS free space, the host allocation of the selected Lima disk, guest free space, and Docker's reclaimable usage. The host report works when the guest is stopped. A sparse disk can run out of host space while the guest still reports space available.

```bash
ducker disk monitor enable 50
ducker disk monitor status
ducker disk monitor disable
```

The optional macOS login agent checks the volume containing Lima storage every five minutes. It logs the first low-space check and sends a macOS notification when permitted. It logs recovery before raising the next alert. The default threshold is 50 GiB. Logs are in `~/Library/Logs/Docker Lab/disk-monitor.log`. Re-enable the monitor after moving the checkout or replacing its installation path.

```bash
ducker disk prune
ducker disk prune --older-than 24h --apply
```

The first command previews reclaimable BuildKit cache last used more than seven days ago, including cache that has never been used. The second applies a 24-hour cutoff and trims the guest filesystem after pruning. Use the same cutoff for preview and apply to compare the candidates. Cache eligibility can change between runs.

## Preview upgrades

```bash
ducker upgrade --plan
ducker upgrade
```

The plan shows the Homebrew packages and available updates, guest package candidates using the VM's current APT metadata, and configured UI image comparisons when the registry is reachable. It shows whether applying the daemon settings would restart Docker. Running `ducker upgrade` updates Homebrew tools and reapplies managed configuration. Guest package and UI image updates shown by the plan are informational.

## Separate development and CI

```bash
ducker instance create work-dev dev "$PWD"
ducker instance create work-ci ci
ducker instance list
ducker --instance work-dev verify
ducker --instance work-ci stop
```

Each instance gets its own guest disk, Docker socket, and Docker context. The development profile uses 2 CPUs, 4 GiB of memory, and a 40 GiB disk. The CI profile uses 4 CPUs, 8 GiB of memory, and an 80 GiB disk. Pass a dedicated project directory for one writable mount. Omitting the directory leaves host mounts disabled. Use distinct host ports across instances.

`ducker --instance NAME` selects the socket for that command. To run Docker directly against a named context without inheriting your shell's default socket, use:

```bash
env -u DOCKER_HOST -u DOCKER_CONTEXT docker --context lima-work-dev ps
```

`ducker instance context work-dev` registers the context again if it is missing. The existing `docker` instance and global Docker context are independent of named instance creation.

## Verify a backup and rehearse recovery

```bash
ducker --instance work-dev backup --vm
ducker backup list
ducker backup verify BACKUP_ID
ducker --instance work-dev restore BACKUP_ID --vm --into work-recovery
```

A VM backup is taken with the source stopped. Verification checks the archived files and their recorded checksums. Restoring into a new name boots a separate recovery VM and verifies that its Docker daemon responds inside the guest. The recovery VM starts without host mounts or a forwarded Docker socket. Use `limactl shell work-recovery` to inspect recovered files and volumes, then stop the rehearsal VM when done. If validation fails, the command attempts to remove the rehearsal instance and tells you if it remains.

## PostgreSQL and Redis

```bash
ducker --instance work-dev lab start
ducker --instance work-dev lab status
ducker --instance work-dev lab stop
```

Compose waits for both services to become healthy. PostgreSQL listens on `127.0.0.1:15432` with database, username, and password `lab`. Redis listens on `127.0.0.1:16379` and uses append-only persistence. These defaults are for local development. Set `LAB_POSTGRES_PORT` and `LAB_REDIS_PORT` at start to avoid port conflicts.

Stopping removes the containers and network and preserves both data volumes. Use `ducker --instance work-dev lab stop --volumes` when you want to delete the lab data.
