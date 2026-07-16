# Installation

![Docker Lab install path](assets/diagrams/install-flow.png)

## What you need

- A Mac with **Apple Silicon** (arm64)
- [Homebrew](https://brew.sh)
- Enough free disk for the VM (default is **200 GiB** — use a smaller [profile](#profiles) if that hurts)
- Some CPU and RAM you’re willing to give the guest (don’t hand it everything)

## Ways to install

### One-liner (easiest)

```bash
curl -fsSL https://raw.githubusercontent.com/nasraldin/docker-lab/main/install.sh | bash
```

That clones or updates `~/homelab/docker-lab`, puts `ducker` on your PATH, then runs `ducker install`.

### Homebrew

```bash
brew tap nasraldin/tools
brew install ducker-lab
ducker install
```

### From a clone

```bash
git clone https://github.com/nasraldin/docker-lab.git ~/homelab/docker-lab
cd ~/homelab/docker-lab
./ducker cli-install
ducker install
```

`ducker install` runs deps → host config → Lima → daemon → verify. You can run it again safely. It does **not** install a UI.

## After it finishes

```bash
ducker status
ducker verify
ducker doctor
ducker about
```

If it just wrote `DOCKER_HOST` into `~/.zshrc`, reload:

```bash
source ~/.zshrc
```

## Profiles

Pick VM size **before** you create the instance (or delete and recreate after changing it):

| Profile | CPUs | Memory | Disk | Good for |
| --- | --- | --- | --- | --- |
| `small` | 4 | 8 GiB | 60 GiB | Lighter machines |
| `balanced` | 6 | 16 GiB | 120 GiB | Day-to-day work |
| `power` | 8 | 24 GiB | 200 GiB | Heavier builds (default-ish) |

```bash
ducker profile list
ducker profile balanced
ducker install               # or ducker lima if you already installed once
```

Leave headroom for macOS. Starving the host makes everything feel broken.

## Optional UI

UIs are separate on purpose:

| Provider | Port | Notes |
| --- | --- | --- |
| `dockhand` | 9090 | Default. Wizard creates the admin user |
| `arcane` | 3552 | Login starts as `arcane` / `arcane-admin` |

```bash
ducker ui install                 # dockhand
ducker ui install arcane
ducker ui open
ducker ui default dockhand
ducker ui uninstall arcane        # UI only — VM stays
```

Secrets live in `apps/ui/<provider>/.env` (gitignored). Which UI is default is stored in `apps/ui/.default`.

## Day to day

```bash
ducker start | stop | restart
ducker status | stats | list
ducker shell
ducker upgrade
ducker backup
ducker restore <backup-id>
```

## Makefile

From the repo, `make` talks to the same scripts `ducker` uses:

```bash
make help
make install
make test
LIVE=1 make test
```

## Wipe and start over

```bash
ducker vm-uninstall              # drop the docker VM only
ducker lab-uninstall             # VM + managed shell/CLI bits
CONFIRM=yes ducker nuke          # everything including ~/.lima and brew packages from the Brewfile
ducker install
```

`nuke` removes all of `~/.lima` (every Lima instance, plus `_config` / `_networks`). Prefer `vm-uninstall` if you only want the `docker` VM gone.

## Where the truth lives

| Path | What it is |
| --- | --- |
| `Brewfile` | Host packages |
| `lima-docker.yaml` | Lima template |
| `config/daemon.json` | Guest rootless dockerd |
| `config/profiles/` | small / balanced / power |
| `apps/ui/<provider>/` | Optional UIs |

Next: [Architecture](architecture.md) · [Troubleshooting](troubleshooting.md)
