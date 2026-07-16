# Docker daemon (rootless)

This stack is **rootless**, so the config that matters is:

```text
# inside Lima
~/.config/docker/daemon.json
```

Not `/etc/docker/daemon.json` — rootless dockerd ignores that.

Peek at it:

```bash
ducker shell
# or:
limactl shell docker -- cat ~/.config/docker/daemon.json
```

## Guest config we ship

File: `config/daemon.json`, applied by `ducker daemon`:

```json
{
  "features": {
    "cdi": true,
    "containerd-snapshotter": true
  },
  "log-driver": "json-file",
  "log-opts": {
    "max-size": "10m",
    "max-file": "3"
  }
}
```

Apply and restart:

```bash
ducker daemon
```

## What those keys mean

| Key | Keep? | Why |
| --- | --- | --- |
| `features.cdi` | Yes | Rosetta CDI device support |
| `features.containerd-snapshotter` | Yes | Modern storage path (`overlayfs`) |
| `log-opts` max-size/file | Yes if containers run a long time | Caps logs (~30 MB per container) |
| `storage-driver: overlay2` | **No** | Fights the containerd snapshotter |
| `features.buildkit: true` | **No** | Redundant on Docker 23+/29 |
| `cliPluginsExtraDirs` | **Never in daemon.json** | Host CLI only — breaks guest dockerd |

Bad keys stop Docker from starting (`directives don't match any configuration option`).

## Host CLI → Lima

Point the host CLI at Lima with `DOCKER_HOST` so the built-in `default` context works:

```bash
export DOCKER_HOST=unix://${HOME}/.lima/docker/sock/docker.sock
unset DOCKER_CONTEXT
```

`ducker config` / `ducker install` write this into `~/.zshrc` between managed markers.

### Why not only `docker context`?

If you only set `DOCKER_CONTEXT=lima-docker`, `default` still points at `/var/run/docker.sock` (Desktop’s path). Then `docker buildx ls` shows a scary `default ... error` even though Lima is fine.

With `DOCKER_HOST`, `default` is Lima and BuildKit looks clean.

## BuildKit / buildx

```bash
docker buildx version
docker buildx ls
docker build .
```

**The default builder is enough.** Don’t create `lima-builder` unless you need multi-node or fancy cache drivers.

Rosetta (amd64) when you need it:

```bash
docker run --platform=linux/amd64 --device=lima-vm.io/rosetta=cached --rm alpine uname -m
```

## Log rotation

With `max-size=10m` and `max-file=3`, Docker rotates then drops the oldest. Existing containers may need a recreate to pick up new log opts:

```bash
docker compose up -d --force-recreate
```

## What `docker info` should look like

```text
Server Version: 29.x
Storage Driver: overlayfs
  driver-type: io.containerd.snapshotter.v1
Logging Driver: json-file
Cgroup Driver: systemd
Cgroup Version: 2
Security Options: rootless
Operating System: Debian GNU/Linux 13 (trixie)
Architecture: aarch64
```
