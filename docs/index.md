# Docker Lab

**A production-grade local Platform Engineering environment for Apple Silicon.**

Not “another Docker Desktop alternative” — a reproducible Linux Docker lab on macOS, managed by one CLI: **`ducker`**.

```text
ducker install  →  Dependencies  →  Lima  →  Docker  →  Config  →  Verify  →  Ready
```

Requires **macOS Apple Silicon (arm64)** and [Homebrew](https://brew.sh).

## Quick install

=== "One-liner"

    ```bash
    curl -fsSL https://raw.githubusercontent.com/nasraldin/docker-lab/main/install.sh | bash
    ```

=== "Homebrew"

    ```bash
    brew tap nasraldin/tools
    brew install ducker-lab
    ducker install
    ```

=== "From source"

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

## Why Docker Lab?

| Feature | Docker Desktop | OrbStack | Docker Lab |
| --- | --- | --- | --- |
| Open source | ❌ | ❌ | ✅ |
| Debian guest | ❌ | ❌ | ✅ |
| Rootless Docker | ✅ | ✅ | ✅ |
| Custom daemon.json | Limited | Partial | ✅ |
| GitOps-ready as code | ❌ | ❌ | ✅ |
| Platform Engineering focus | ❌ | ❌ | ✅ |

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
| `ducker ui …` | Optional Docker UIs (Dockhand default) |
| `ducker nuke` | Full wipe (`CONFIRM=yes` to skip prompt) |

## Next steps

- [Installation](installation.md) — profiles, first boot, UI
- [CLI reference](cli-reference.md) — every command with simulated output
- [Architecture](architecture.md) — Lima + Debian + rootless Docker
- [Troubleshooting](troubleshooting.md) — symptoms, fixes, what **not** to do
- [Roadmap](roadmap.md) — toward a Developer Platform CLI
- [Docs site](docs-site.md) — preview locally with MkDocs / GitHub Pages

## Source

GitHub: [nasraldin/docker-lab](https://github.com/nasraldin/docker-lab)
