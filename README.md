# Docker Lab

[![CI](https://github.com/nasraldin/docker-lab/actions/workflows/ci.yml/badge.svg)](https://github.com/nasraldin/docker-lab/actions/workflows/ci.yml)
[![Docs](https://github.com/nasraldin/docker-lab/actions/workflows/docs.yml/badge.svg)](https://github.com/nasraldin/docker-lab/actions/workflows/docs.yml)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)
[![Latest Release](https://img.shields.io/github/v/release/nasraldin/docker-lab?display_name=tag&sort=semver)](https://github.com/nasraldin/docker-lab/releases/latest)
[![Downloads](https://img.shields.io/github/downloads/nasraldin/docker-lab/total.svg)](https://github.com/nasraldin/docker-lab/releases)
[![Docs site](https://img.shields.io/badge/docs-GitHub%20Pages-teal)](https://nasraldin.github.io/docker-lab/)

**A production-grade local Platform Engineering environment for Apple Silicon.**

Not “another Docker Desktop alternative” — a reproducible Linux Docker lab on macOS, managed by one CLI: **`ducker`**.

```text
ducker install  →  Dependencies  →  Lima  →  Docker  →  Config  →  Verify  →  Ready
```

Requires **macOS Apple Silicon (arm64)** and [Homebrew](https://brew.sh).

---

## Why Docker Lab?

| Feature | Docker Desktop | OrbStack | Docker Lab |
| --- | --- | --- | --- |
| Open source | ❌ | ❌ | ✅ |
| Debian guest | ❌ | ❌ | ✅ |
| Rootless Docker | ✅ | ✅ | ✅ |
| Custom daemon.json | Limited | Partial | ✅ |
| GitOps-ready as code | ❌ | ❌ | ✅ |
| Platform Engineering focus | ❌ | ❌ | ✅ |

Stack: **Lima + Debian 13 + rootless Docker Engine** (vz, virtiofs, Rosetta).

---

## Install

### One-liner

```bash
curl -fsSL https://raw.githubusercontent.com/nasraldin/docker-lab/main/install.sh | bash
```

### Homebrew (tap)

```bash
brew tap nasraldin/tools
brew install ducker-lab
```

First-time tap setup and CI publish: [Homebrew docs](https://nasraldin.github.io/docker-lab/homebrew/).

### From source

```bash
git clone https://github.com/nasraldin/docker-lab.git ~/homelab/docker-lab
cd ~/homelab/docker-lab
./ducker cli-install
ducker install
```

Then:

```bash
ducker status
ducker verify
ducker doctor
```

Optional UI:

```bash
ducker ui install          # Dockhand (default)
ducker ui install arcane
ducker ui open
```

---

## `ducker` at a glance

| Command | What it does |
| --- | --- |
| `ducker install` | Full lab one-shot (idempotent) |
| `ducker verify` / `doctor` / `diagnose` | Health checks & diagnostics |
| `ducker doctor --fix` | Apply common host/guest fixes |
| `ducker status` / `stats` | VM + Docker status / live stats |
| `ducker benchmark` | Disk I/O, pull, and build timing |
| `ducker upgrade` | Safely update brew tools + re-apply config |
| `ducker backup` / `restore` | Snapshot lab config (and optional VM) |
| `ducker profile <name>` | Tune VM: `small` \| `balanced` \| `power` |
| `ducker self-test` | Alias for `ducker test` |
| `ducker ui …` | Optional Docker UIs |
| `ducker nuke` | Full wipe (`CONFIRM=yes` to skip prompt) |

```bash
ducker about               # project + runtime card
ducker help                # full command list
LIVE=1 ducker test         # runtime validation (needs Running VM)
```

See [Installation](https://nasraldin.github.io/docker-lab/installation/) for profiles, disk sizing, and day-to-day ops.

---

## Architecture

```text
macOS (Apple Silicon)
  └── Homebrew → limactl, docker CLI, compose, buildx
        │
        ▼  DOCKER_HOST=unix://~/.lima/docker/sock/docker.sock
  Lima VM (vz + virtiofs + Rosetta)
        └── Debian 13 (aarch64)
              └── Docker Engine (rootless) → containerd → containers
```

Details: [Architecture](https://nasraldin.github.io/docker-lab/architecture/)

---

## Documentation

**Site:** [https://nasraldin.github.io/docker-lab/](https://nasraldin.github.io/docker-lab/)

| Doc | Contents |
| --- | --- |
| [Installation](https://nasraldin.github.io/docker-lab/installation/) | Install paths, profiles, first boot |
| [Architecture](https://nasraldin.github.io/docker-lab/architecture/) | Stack, Lima 2.x rules, sizing |
| [Docker daemon](https://nasraldin.github.io/docker-lab/docker-daemon/) | Rootless `daemon.json`, BuildKit |
| [Performance](https://nasraldin.github.io/docker-lab/performance/) | Mounts, volumes, benchmarks |
| [Troubleshooting](https://nasraldin.github.io/docker-lab/troubleshooting/) | Symptoms → fixes + what **not** to do |
| [FAQ](https://nasraldin.github.io/docker-lab/faq/) | Common questions |
| [Advanced](https://nasraldin.github.io/docker-lab/advanced/) | Manual setup, backup/restore, upgrade |
| [Comparison](https://nasraldin.github.io/docker-lab/comparison/) | vs Docker Desktop / OrbStack |
| [Roadmap](https://nasraldin.github.io/docker-lab/roadmap/) | Toward a Developer Platform CLI |
| [Docs site](https://nasraldin.github.io/docker-lab/docs-site/) | Preview locally + GitHub Pages |
| [Homebrew](https://nasraldin.github.io/docker-lab/homebrew/) | Tap setup + release automation |
| [Releasing](https://nasraldin.github.io/docker-lab/releasing/) | Tags, Homebrew, GitHub Releases |

Source markdown lives in [`docs/`](docs/). Preview locally:

```bash
python3 -m venv .venv-docs
source .venv-docs/bin/activate
pip install -r requirements-docs.txt
make docs-serve
```

---

## Validation

```bash
ducker test                # static (safe anytime)
LIVE=1 ducker test         # needs Running VM
ducker verify
ducker doctor
ducker benchmark           # optional performance baseline
```

CI on every PR: ShellCheck, shfmt, markdownlint, yamllint, actionlint, `make test`.

---

## Roadmap (one CLI)

```text
Docker Lab → Compose Lab → Kind / Talos → Kubernetes → GitOps → Platform Lab
```

Today: `ducker install` brings up Docker. Tomorrow: `ducker install kind`, `argocd`, `prometheus`, …  
See [Roadmap](https://nasraldin.github.io/docker-lab/roadmap/).

---

## License

MIT — see [LICENSE](LICENSE).
