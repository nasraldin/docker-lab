# Docker Lab

Run real Linux Docker on Apple Silicon without the usual Desktop tax. The VM rides Apple’s native Virtualization framework (`vz`), so you’re not dragging a heavy hypervisor around — better for CPU, RAM, and battery. Debian 13 in Lima, rootless Docker Engine, and a small CLI called **`ducker`** that installs and checks the whole thing.

![Docker Lab install path: ducker install → Dependencies → Lima → Docker → Config → Verify → Ready](assets/diagrams/install-flow.png)

Needs **macOS on Apple Silicon** and [Homebrew](https://brew.sh).

## Install

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

## Why this instead of Desktop?

|                          | Docker Desktop | OrbStack | Docker Lab |
| ------------------------ | -------------- | -------- | ---------- |
| Open source              | No             | No       | Yes        |
| Debian guest             | No             | No       | Yes        |
| Rootless                 | Yes            | Yes      | Yes        |
| You own `daemon.json`    | Limited        | Partial  | Yes        |
| Config lives in the repo | No             | No       | Yes        |

## Commands you’ll use most

| Command                     | Meaning                                     |
| --------------------------- | ------------------------------------------- |
| `ducker install`            | Full setup (safe to re-run)                 |
| `ducker verify` / `doctor`  | Is it healthy?                              |
| `ducker doctor --fix`       | Apply the usual fixes                       |
| `ducker status` / `stats`   | What’s running                              |
| `ducker upgrade`            | Update tools + re-apply config              |
| `ducker backup` / `restore` | Snapshot config                             |
| `ducker profile …`          | `small` / `balanced` / `power`              |
| `ducker ui …`               | Optional web UI (Dockhand by default)       |
| `ducker nuke`               | Wipe the lab (`CONFIRM=yes` to skip prompt) |

## Where to go next

- [Installation](installation.md) — profiles, disk size, first boot
- [CLI reference](cli-reference.md) — every command with sample output
- [Architecture](architecture.md) — how the pieces connect
- [Troubleshooting](troubleshooting.md) — when something breaks
- [Roadmap](roadmap.md) — longer-term plans

## Source

[github.com/nasraldin/docker-lab](https://github.com/nasraldin/docker-lab)
