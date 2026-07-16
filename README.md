# macOS Homelab: Lima + Debian 13 + Docker Engine

Professional install-and-run guide for a fast, production-like Docker lab on Apple Silicon.

Use **`ducker`** as the global CLI. It wraps this repo’s Makefile and scripts so you can install, manage, and verify the lab from any directory. The sections below document the underlying Lima + Docker setup in detail.

This documents the **validated** stack (not generic Docker Desktop advice). Several common recommendations fail on Lima 2.x / rootless Docker / containerd v2 — those traps are called out below.

---

## Global CLI (`ducker`)

`ducker` is a bash script in this repo. Install it once globally, then run the whole lab without `cd` into the project folder.

### Get the repo

```bash
git clone https://github.com/nasraldin/docker-lab.git ~/homelab/docker-lab
cd ~/homelab/docker-lab
```

### Install the global command

```bash
ducker cli-install          # symlinks → ~/.local/bin/ducker (or /usr/local/bin)
ducker about                # project info card
ducker help                 # full command list
```

Manual symlink (same result):

```bash
ln -sf ~/homelab/docker-lab/ducker ~/.local/bin/ducker
# ensure ~/.local/bin is on your PATH
```

Remove the global link:

```bash
ducker cli-uninstall
```

### First-time lab setup

From **any directory** after `cli-install`:

```bash
ducker install              # deps + config + lima + daemon + verify (no UI)
ducker status               # Lima VM + Docker engine
ducker verify               # health checks
ducker doctor               # status + verify
```

Optional Docker UI (not part of `install`):

```bash
ducker ui install           # arcane (default)
ducker ui install dockhand
ducker ui open
ducker ui status
```

### Everyday commands

| Command | What it does |
| --- | --- |
| `ducker install` | Full lab one-shot (idempotent) |
| `ducker deps` | Homebrew packages (`Brewfile`) |
| `ducker config` | `~/.docker/config.json` plugins + `DOCKER_HOST` in `~/.zshrc` |
| `ducker lima` | Create/start Lima VM from `lima-docker.yaml` |
| `ducker daemon` | Apply guest rootless `daemon.json` + restart Docker |
| `ducker verify` | Host tools, VM, Docker, buildx checks |
| `ducker start` \| `stop` \| `restart` | Lima VM lifecycle |
| `ducker status` \| `list` | VM + Docker summary |
| `ducker shell` | Interactive shell in the Debian guest |
| `ducker ui …` | Optional UI: `install`, `up`, `down`, `open`, `status`, `default`, `uninstall` |
| `ducker test` | Project self-test (static; safe anytime) |
| `LIVE=1 ducker test` | Full runtime test (needs Running VM) |
| `ducker test-run` | alpine + stress-ng smoke test |
| `ducker vm-uninstall` | Delete Lima VM only |
| `ducker lab-uninstall` | VM + managed host shell/CLI config |
| `ducker nuke` | Full wipe — brew packages, caches, VM (`CONFIRM=yes` to skip prompt) |
| `ducker about` | Author, version, paths, runtime status |
| `ducker version` | Short version string |

Examples:

```bash
ducker install
ducker status
ducker ui install dockhand
ducker ui open
LIVE=1 ducker test
CONFIRM=yes ducker nuke    # destructive — reinstall with ducker install after
```

Project metadata (version, tagline, author) lives in `config.env` and shows in `ducker about`.

Requires **macOS Apple Silicon (arm64)**, Homebrew, and enough free disk for a ~200 GiB Lima disk (edit `lima-docker.yaml` to shrink if needed).

---

## Quick start (Makefile)

You can also use `make` from the repo directory — `ducker` calls the same targets under the hood.

```bash
cd ~/homelab/docker-lab
make cli-install            # global ducker
ducker install
ducker status
LIVE=1 make test            # after install: validate running stack
```

Or without the global CLI:

```bash
make help
make test                   # self-test (safe; no VM destroy)
make install                # ONE-SHOT: deps + config + lima + daemon + verify
make status
```

### Command cheat sheet

| Goal | Command |
| --- | --- |
| Global CLI (from any directory) | `make cli-install` then `ducker …` |
| Fresh / full lab setup | `ducker install` or `make install` |
| Re-apply one piece after edits | `ducker deps` / `config` / `lima` / `daemon` / `verify` |
| Optional Docker UI | `ducker ui install [arcane\|dockhand]` |
| Day-to-day VM | `ducker start` \| `stop` \| `status` \| `shell` |
| Wipe | `ducker vm-uninstall` or `ducker nuke` (`CONFIRM=yes` to skip prompt) |

`make install` / `ducker install` is idempotent: safe to re-run. Neither installs a UI (keep that opt-in).

```bash
# After changing lima-docker.yaml or daemon.json, only re-run what changed:
ducker lima
ducker daemon

# Optional UI (separate from install)
ducker ui install              # Arcane by default
ducker ui install dockhand
ducker ui open
ducker ui uninstall dockhand   # UI only — does NOT delete the VM
```

`ducker nuke` wipes the lab for a fresh Mac reset (keeps this git folder).

Single sources of truth: `Brewfile`, `config/`, `lima-docker.yaml`, `apps/ui/<provider>/`.

### Optional: UI providers

UI apps are **not** part of `ducker install`. Supported providers:

| Provider | Port | Notes |
| --- | --- | --- |
| `arcane` | 3552 | Default if you omit the name. Login: `arcane` / `arcane-admin` |
| `dockhand` | 9090 | First-run wizard creates admin |

```bash
ducker ui install                 # → arcane, becomes default
ducker ui install dockhand        # may ask which default if both exist
ducker ui open                    # uses apps/ui/.default
ducker ui default dockhand
```

Secrets per provider: `apps/ui/<provider>/.env` (gitignored). Default marker: `apps/ui/.default`.

---

## Goal

Run Docker on macOS with:

- Apple Virtualization (`vz`) for near-native performance
- Debian 13 (Trixie) guest — aligned with typical Linux/Kubernetes labs
- Docker Engine inside Lima (not Docker Desktop)
- Host `docker` / `compose` / `buildx` talking to the Lima socket
- Sensible defaults for long-running services and builds

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

**Target hardware example:** MacBook Pro M1 Max, 64 GB RAM.
**Validated tooling (reference):** Lima `2.1.4`, Docker Client/Server `29.x`.

---

## Architecture notes that matter

| Topic | Fact |
| --- | --- |
| Guest arch (`uname -m`) | `aarch64` (Linux name). Same CPU as macOS `arm64`. |
| Docker platform | `linux/arm64` |
| VM type | `vz` (Apple Virtualization Framework) — prefer over `qemu` on Apple Silicon |
| Mounts | VirtioFS via VZ — avoid putting hot paths like `node_modules` on Mac bind mounts |
| Docker mode | **Rootless** in this profile |
| Storage | `overlayfs` via **containerd snapshotter** (not classic `overlay2` daemon flag) |
| BuildKit | Built into the daemon; host needs `docker-buildx` plugin |

---

## Prerequisites

- macOS on Apple Silicon
- [Homebrew](https://brew.sh)
- Enough free disk (this profile uses a **200 GiB** VM disk)
- Willingness to allocate **8 CPUs / 24 GiB RAM** to the VM (leave headroom for macOS)

Optional later (not required for Docker itself):

```bash
brew install kubectl helm terraform ansible
```

---

## Manual setup (Lima, Docker CLI, daemon)

> **Automated path:** `ducker install` runs the steps in sections 1–4 below. Use this guide to understand, customize, or debug each piece.

## 1. Install host tools

```bash
brew install lima docker docker-compose docker-buildx yq jq
```

### Optional: Lima guest agents

```text
brew install lima-additional-guestagents
```

**Skip** for a native `aarch64` Debian VM on Apple Silicon.
Install only if you need **non-native** guest architectures (e.g. x86_64 guests) with Lima’s extra agents.

### Wire Homebrew Docker plugins

Homebrew installs compose/buildx under:

```text
/opt/homebrew/lib/docker/cli-plugins
```

Docker CLI must be told about that directory.

```bash
mkdir -p ~/.docker
```

Create or merge `~/.docker/config.json`:

```json
{
  "cliPluginsExtraDirs": [
    "/opt/homebrew/lib/docker/cli-plugins"
  ]
}
```

Verify plugins:

```bash
docker compose version
docker buildx version
```

At this stage `docker version` may show **Client only** and fail to reach a daemon — expected until Lima is running.

---

## 2. Lima config (Debian 13 + Docker)

### Important Lima 2.x rules

1. A template **must** provide guest images (`images:` or `base: template:_images/...`).
   A YAML with only `cpus` / `memory` / `disk` will fail with:
   `field images must be set`.
2. Keep templates **outside** `~/.lima/<instance>/`.
   That directory is for running instances, not source files.
3. Prefer starting with an explicit name:

```bash
limactl start --name=docker /path/to/lima-docker.yaml
```

### Resource sizing (M1 Max / 64 GB)

| Resource | Value | Why |
| --- | --- | --- |
| CPUs | 8 | Strong builds without starving macOS |
| Memory | 24 GiB | Postgres/Redis/Node stacks; leave ~40 GiB+ for macOS |
| Disk | 200 GiB | Images, layers, build cache |
| `vmType` | `vz` | Fastest path on Apple Silicon |
| Rosetta | enabled | Run/build `linux/amd64` when needed |

Do **not** assign almost all RAM/CPU to the VM.

### Install the template

This repo/folder includes `lima-docker.yaml`. Copy it somewhere stable:

```bash
cp lima-docker.yaml ~/lima-docker.yaml
```

Or use the copy next to this README.

Key design points of that file:

- Base image: Debian 13 (`template:_images/debian-13`)
- Installs Docker via get.docker.com
- Configures **rootless** Docker
- Enables CDI + containerd snapshotter (needed for Rosetta CDI device)
- Forwards guest docker socket → `~/.lima/docker/sock/docker.sock`

> Do **not** start from vanilla `template://docker` if you want Debian 13.
> The official Docker template pulls Ubuntu LTS images.

---

## 3. Create and start the instance

```bash
# First create/start
limactl start --name=docker ~/lima-docker.yaml

# Later day-to-day
limactl start docker
limactl stop docker
limactl restart docker
limactl list
```

First boot downloads the Debian cloud image and expands the 200 GiB disk — expect several minutes.

### If start fails: stale hostagent

Symptom:

```text
another hostagent may already be running with pid ...
```

or instance stuck `Stopped` after a partial start.

Fix:

```bash
limactl stop -f docker
limactl start docker
```

### Harmless warning on restart

```text
WARN failed to listen tcp: 127.0.0.1:5355: address already in use
```

LLMNR/name-discovery port collision on the host. Docker still becomes `READY`. Ignore unless you specifically need that forward.

---

## 4. Point the Mac Docker CLI at Lima

For a **Lima-only** machine, set `DOCKER_HOST` so the built-in `default` context works (and `docker buildx ls` does not error on missing `/var/run/docker.sock`).

Add to `~/.zshrc`:

```bash
# Lima is the only Docker daemon — point the default client at its socket.
export DOCKER_HOST=unix://${HOME}/.lima/docker/sock/docker.sock
unset DOCKER_CONTEXT
```

Reload:

```bash
source ~/.zshrc
```

Verify:

```bash
docker version
docker info
docker context ls
docker buildx ls
```

Expected highlights from `docker info`:

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
Docker Root Dir: /home/<user>.guest/.local/share/docker
```

### Why not `docker context` only?

Using only `DOCKER_CONTEXT=lima-docker` leaves the built-in `default` context pointing at `/var/run/docker.sock` (Docker Desktop path).
Then `docker buildx ls` shows a scary `default ... error` even though Lima works.

With `DOCKER_HOST`, `default` becomes Lima and BuildKit looks clean:

```text
NAME/NODE     DRIVER/ENDPOINT   STATUS    BUILDKIT   PLATFORMS
default*      docker            running   v0.x       linux/arm64
```

You may still see a note that `DOCKER_HOST` overrides contexts — fine when Lima is your only daemon.

---

## 5. Guest Docker daemon config (rootless)

Because this stack is **rootless**, the effective config is:

```text
# inside Lima
~/.config/docker/daemon.json
```

**Not** `/etc/docker/daemon.json` (ignored by rootless dockerd).

Inspect:

```bash
limactl shell docker
cat ~/.config/docker/daemon.json
```

### Recommended guest config

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

Apply + restart user Docker:

```bash
limactl shell docker -- bash -lc 'cat > ~/.config/docker/daemon.json <<EOF
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
EOF
systemctl --user restart docker'
```

### What those keys mean

| Key | Keep? | Why |
| --- | --- | --- |
| `features.cdi` | Yes | Rosetta CDI device support |
| `features.containerd-snapshotter` | Yes | Modern storage path (`overlayfs`) |
| `log-opts` max-size/file | Yes if services run 24/7 | Rotates logs (~30 MB/container max) |
| `storage-driver: overlay2` | **No** | Fights containerd snapshotter; not needed |
| `features.buildkit: true` | **No** | Redundant on Docker 23+/29 |
| `cliPluginsExtraDirs` | **Never in daemon.json** | Host CLI-only; breaks guest dockerd |

Invalid keys in `daemon.json` prevent Docker from starting (`directives don't match any configuration option`).

### Log rotation behavior

With `max-size=10m` and `max-file=3`, Docker **rotates** files (keeps ~3 × 10 MB), then drops the oldest. It does not wipe a single log and restart empty.

Existing containers may need recreate to pick up new log opts:

```bash
docker compose up -d --force-recreate
```

---

## 6. BuildKit / buildx

Install host plugin (already covered):

```bash
brew install docker-buildx
```

Confirm:

```bash
docker buildx version
docker buildx ls
```

**Default builder is enough.** Do not create `lima-builder` unless you need multi-node / advanced cache drivers.

```bash
docker build .
# or
docker buildx build .
```

Rosetta (amd64) example when needed:

```bash
docker run --platform=linux/amd64 --device=lima-vm.io/rosetta=cached --rm alpine uname -m
```

---

## 7. Validation checklist

### VM

```bash
limactl list
limactl shell docker -- uname -m     # aarch64
limactl shell docker -- nproc        # 8
limactl shell docker -- free -h      # ~24Gi
```

### Docker

```bash
docker run --rm hello-world
docker run --rm alpine uname -a
docker compose version
docker buildx ls
```

### Load test (modern image)

`progrium/stress` uses obsolete manifest v1 and **fails** on containerd v2.1+. Use stress-ng:

```bash
docker run --rm ghcr.io/colinianking/stress-ng \
  --cpu 4 --vm 2 --vm-bytes 1G --timeout 30s --metrics-brief
```

Healthy signs: `failed: 0`, CPU usr time ≈ `workers × duration`, no OOM.

The `sched_autogroup_enabled` note from stress-ng is optional / benchmark-only. Ignore for daily use.

---

## 8. Day-to-day operations

```bash
# Start / stop lab VM
limactl start docker
limactl stop docker

# Shell into Debian
limactl shell docker

# Docker from macOS (uses DOCKER_HOST)
docker ps
docker compose up -d
```

### Recreate from scratch

```bash
limactl delete -f docker
limactl start --name=docker ~/lima-docker.yaml
```

### Faster Compose/dev mounts

Mac bind mounts are convenient but expensive for chatty trees.

Prefer named volumes for:

- `node_modules`
- `.next`
- package caches
- databases

```yaml
services:
  app:
    volumes:
      - .:/app
      - node_modules:/app/node_modules
volumes:
  node_modules:
```

---

## 9. Troubleshooting

| Symptom | Fix |
| --- | --- |
| `field images must be set` | Use a Lima 2 template with `base:` / images (this `lima-docker.yaml`) |
| Instance `Stopped`, no disk | Incomplete first start / interrupted download → `limactl stop -f docker && limactl start docker` |
| `another hostagent may already be running` | `limactl stop -f docker` then start again |
| `cliPluginsExtraDirs` in daemon.json → Docker won’t start | Remove it from guest daemon.json; keep it only in `~/.docker/config.json` on the Mac |
| buildx `default` error on `/var/run/docker.sock` | Set `DOCKER_HOST` to Lima socket (section 4) |
| `manifest.v1+prettyjws is no longer supported` | Image is too old — pick a maintained image |
| Compose/buildx “unknown command” | Fix `cliPluginsExtraDirs` + `brew install docker-compose docker-buildx` |

Logs:

```bash
# Host agent
tail -f ~/.lima/docker/ha.stderr.log

# Guest boot / cloud-init
limactl shell docker -- sudo tail -f /var/log/cloud-init-output.log

# Rootless docker
limactl shell docker -- journalctl --user -u docker -f
```

---

## 10. What **not** to do (lessons learned)

1. Do **not** put custom templates under `~/.lima/<name>/lima.yaml` as the primary workflow.
2. Do **not** use ChatGPT’s bare Lima YAML without `images` / `base` on Lima 2.x.
3. Do **not** configure rootless Docker via `/etc/docker/daemon.json`.
4. Do **not** force `"storage-driver": "overlay2"` when using containerd snapshotter.
5. Do **not** put host-only Docker CLI keys into guest `daemon.json`.
6. Do **not** rely on `progrium/stress` on modern containerd.
7. Do **not** create an extra buildx builder “just because” — default is fine.
8. Do **not** give the VM nearly all host RAM/CPU.

---

## 11. Optional next steps (homelab path)

After this Docker lab is solid:

1. Inspect internals inside Lima: `dockerd`, `containerd`, `runc`, cgroups v2, iptables/nft
2. Run Compose stacks for app + Postgres + Redis
3. Keep Kubernetes learning on dedicated Linux/Proxmox nodes (`kubeadm`), not inside this Mac Docker VM

Suggested learning progression:

```text
Linux → Docker → containerd → Compose → (later) kubeadm on Proxmox
```

---

## Quick reference

```bash
# Install
brew install lima docker docker-compose docker-buildx yq jq

# Plugins: ~/.docker/config.json → cliPluginsExtraDirs → /opt/homebrew/lib/docker/cli-plugins
# Shell:   export DOCKER_HOST=unix://${HOME}/.lima/docker/sock/docker.sock

# VM
limactl start --name=docker ~/lima-docker.yaml
limactl list
limactl shell docker

# Sanity
docker run --rm hello-world
docker buildx ls
```

Files:

| Path | Role |
| --- | --- |
| `~/lima-docker.yaml` | Source Lima template (Debian 13 + Docker) |
| `~/.lima/docker/` | Running instance data (do not hand-edit as a template) |
| `~/.docker/config.json` | Host CLI plugins |
| `~/.zshrc` | `DOCKER_HOST` |
| Guest `~/.config/docker/daemon.json` | Rootless dockerd settings |

---

## Testing before you publish

Two layers — don’t confuse them:

| Command | What it does | Needs a running VM? |
| --- | --- | --- |
| `ducker test` / `make test` | Static checks: files, bash syntax, Makefile dry-runs, UI collision safety | **No** (safe anytime) |
| `LIVE=1 ducker test` | Also runs `verify.sh`, `hello-world`, UI list against your Lima Docker | **Yes** — after a successful `ducker install` |

```bash
# On a clean machine / before release:
ducker nuke                 # optional: wipe old lab
ducker test                 # must PASS (static)
ducker install              # full stack
LIVE=1 ducker test          # must PASS against Running VM
ducker about                # branding card looks right
ducker ui install           # optional product path
```

If `make test` “doesn’t work correctly”, usually you ran live expectations without `LIVE=1`, or `install` never finished (e.g. old `--no-lock` / compose-plugin order bugs). Fix install first, then re-run tests.

## Publish for others (GitHub)

1. Put the repo on GitHub (public), keep secrets out (`.env` is gitignored; only `.env.example`).
2. Tag a release (`v1.0.0` matches `config.env` / `ducker about`).
3. README Quick start is the install path users follow:
   ```bash
   git clone https://github.com/nasraldin/docker-lab.git
   cd docker-lab
   ducker cli-install
   ducker install
   ducker status
   ```
4. Requirements to state clearly: **macOS Apple Silicon**, Homebrew, ~200 GiB free (or edit `lima-docker.yaml` disk).
5. Optional: GitHub Actions that runs `make test` on `macos-latest` (arm64) for static checks; live VM tests stay manual or a dedicated self-hosted Mac runner.

## License / sharing

MIT — see `LICENSE`. Keep the “what not to do” section; it prevents the most common Lima + Docker Desktop migration mistakes.
