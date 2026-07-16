# Docker daemon (rootless)

Because this stack is **rootless**, the effective config is:

```text
# inside Lima
~/.config/docker/daemon.json
```

**Not** `/etc/docker/daemon.json` (ignored by rootless dockerd).

Inspect:

```bash
ducker shell
# or:
limactl shell docker -- cat ~/.config/docker/daemon.json
```

## Recommended guest config

Shipped as `config/daemon.json` and applied by `ducker daemon`:

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

Apply + restart:

```bash
ducker daemon
```

## What those keys mean

| Key | Keep? | Why |
| --- | --- | --- |
| `features.cdi` | Yes | Rosetta CDI device support |
| `features.containerd-snapshotter` | Yes | Modern storage path (`overlayfs`) |
| `log-opts` max-size/file | Yes if services run 24/7 | Rotates logs (~30 MB/container max) |
| `storage-driver: overlay2` | **No** | Fights containerd snapshotter |
| `features.buildkit: true` | **No** | Redundant on Docker 23+/29 |
| `cliPluginsExtraDirs` | **Never in daemon.json** | Host CLI-only; breaks guest dockerd |

Invalid keys prevent Docker from starting (`directives don't match any configuration option`).

## Host CLI → Lima

For a Lima-only machine, set `DOCKER_HOST` so the built-in `default` context works:

```bash
export DOCKER_HOST=unix://${HOME}/.lima/docker/sock/docker.sock
unset DOCKER_CONTEXT
```

`ducker config` / `ducker install` writes this into `~/.zshrc` between managed markers.

### Why not `docker context` only?

Using only `DOCKER_CONTEXT=lima-docker` leaves `default` pointing at `/var/run/docker.sock` (Docker Desktop path). Then `docker buildx ls` shows a scary `default ... error` even though Lima works.

With `DOCKER_HOST`, `default` becomes Lima and BuildKit looks clean.

## BuildKit / buildx

```bash
docker buildx version
docker buildx ls
docker build .
```

**Default builder is enough.** Do not create `lima-builder` unless you need multi-node / advanced cache drivers.

Rosetta (amd64) when needed:

```bash
docker run --platform=linux/amd64 --device=lima-vm.io/rosetta=cached --rm alpine uname -m
```

## Log rotation

With `max-size=10m` and `max-file=3`, Docker rotates files then drops the oldest. Existing containers may need recreate to pick up new log opts:

```bash
docker compose up -d --force-recreate
```

## Expected `docker info` highlights

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
