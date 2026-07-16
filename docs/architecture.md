# Architecture

## Positioning

Docker Lab is a **production-grade local Platform Engineering environment for Apple Silicon** — not a thin “Docker Desktop replacement.”

It optimizes for:

- Reproducible Linux guests (Debian 13)
- Rootless Docker Engine with a real `daemon.json`
- Host CLI → Lima socket (`DOCKER_HOST`)
- Idempotent install, verify, doctor, and GitOps-friendly config-as-code

## Stack diagram

```text
macOS (Apple Silicon)
  └── Homebrew
        ├── limactl
        ├── docker (CLI)
        ├── docker-compose (plugin)
        └── docker-buildx (plugin)
              │
              ▼  DOCKER_HOST=unix://~/.lima/docker/sock/docker.sock
        Lima VM (vz + virtiofs + Rosetta)
              └── Debian 13 (aarch64)
                    └── Docker Engine (rootless)
                          └── containerd + runc
                                └── containers
```

**Validated tooling (reference):** Lima `2.x`, Docker Client/Server `29.x`.

## Facts that matter

| Topic | Fact |
| --- | --- |
| Guest arch (`uname -m`) | `aarch64` (same silicon as macOS `arm64`) |
| Docker platform | `linux/arm64` |
| VM type | `vz` (Apple Virtualization) — prefer over `qemu` on Apple Silicon |
| Mounts | VirtioFS via VZ — avoid hot paths like `node_modules` on Mac bind mounts |
| Docker mode | **Rootless** in the default profile |
| Storage | `overlayfs` via **containerd snapshotter** (not classic `overlay2` daemon flag) |
| BuildKit | Built into the daemon; host needs `docker-buildx` plugin |

## Lima 2.x rules

1. A template **must** provide guest images (`images:` or `base: template:_images/...`).
   A YAML with only `cpus` / `memory` / `disk` fails with: `field images must be set`.
2. Keep templates **outside** `~/.lima/<instance>/` — that directory is for running instances.
3. Prefer an explicit name: `limactl start --name=docker /path/to/lima-docker.yaml`.

Do **not** start from vanilla `template://docker` if you want Debian 13 — the official Docker template uses Ubuntu LTS.

## Resource sizing

Defaults match the `power` profile (M1 Max / 64 GB class hosts):

| Resource | Default | Why |
| --- | --- | --- |
| CPUs | 8 | Strong builds without starving macOS |
| Memory | 24 GiB | Postgres/Redis/Node stacks; leave headroom for macOS |
| Disk | 200 GiB | Images, layers, build cache |
| `vmType` | `vz` | Fastest path on Apple Silicon |
| Rosetta | enabled | Run/build `linux/amd64` when needed |

Use `ducker profile small|balanced|power` on smaller machines — see [installation.md](installation.md#profiles).

## Install flow

```text
ducker install
  → deps (Brewfile)
  → config (CLI plugins + DOCKER_HOST in ~/.zshrc)
  → lima (create/start from lima-docker.yaml)
  → daemon (guest ~/.config/docker/daemon.json + restart)
  → verify
```

## Files on disk

| Path | Role |
| --- | --- |
| `lima-docker.yaml` | Source template |
| `~/.lima/docker/` | Running instance (do not hand-edit as a template) |
| `~/.docker/config.json` | Host CLI plugins (`cliPluginsExtraDirs`) |
| `~/.zshrc` | Managed `DOCKER_HOST` block |
| Guest `~/.config/docker/daemon.json` | Rootless dockerd settings |

Next: [Docker daemon](docker-daemon.md) · [Performance](performance.md)
