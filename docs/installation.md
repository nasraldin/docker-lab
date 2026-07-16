# Installation

## Requirements

- macOS on **Apple Silicon** (arm64)
- [Homebrew](https://brew.sh)
- Free disk for the Lima VM (default **200 GiB**; shrink via profile or `lima-docker.yaml`)
- Willingness to allocate CPU/RAM to the VM (see [Profiles](#profiles))

## Install paths

### One-liner (recommended)

```bash
curl -fsSL https://raw.githubusercontent.com/nasraldin/docker-lab/main/install.sh | bash
```

This clones (or updates) the repo under `~/homelab/docker-lab`, links `ducker` on your PATH, then runs `ducker install`.

### Homebrew tap

```bash
brew tap nasraldin/tools
brew install ducker-lab
ducker install
```

### From source

```bash
git clone https://github.com/nasraldin/docker-lab.git ~/homelab/docker-lab
cd ~/homelab/docker-lab
./ducker cli-install
ducker install
```

`ducker install` is **idempotent**: deps → host config → Lima → daemon → verify. It does **not** install a UI.

## After install

```bash
ducker status
ducker verify
ducker doctor
ducker about
```

Reload your shell if `DOCKER_HOST` was just written to `~/.zshrc`:

```bash
source ~/.zshrc
```

## Profiles

Tune VM CPU, memory, and disk **before** first create (or recreate the VM after changing profile):

| Profile | CPUs | Memory | Disk | Use when |
| --- | --- | --- | --- | --- |
| `small` | 4 | 8 GiB | 60 GiB | Laptops with limited RAM |
| `balanced` | 6 | 16 GiB | 120 GiB | Day-to-day Compose / builds |
| `power` | 8 | 24 GiB | 200 GiB | Default — heavy builds & services |

```bash
ducker profile list
ducker profile balanced      # writes active profile + patches lima template values
ducker install               # or: ducker lima  (after a prior install)
```

Do **not** give the VM nearly all host RAM/CPU.

## Optional Docker UI

UI is opt-in (not part of `ducker install`):

| Provider | Port | Notes |
| --- | --- | --- |
| `dockhand` | 9090 | Default. First-run wizard creates admin |
| `arcane` | 3552 | Login: `arcane` / `arcane-admin` |

```bash
ducker ui install                 # → dockhand
ducker ui install arcane
ducker ui open
ducker ui default dockhand
ducker ui uninstall arcane        # UI only — does not delete the VM
```

Secrets: `apps/ui/<provider>/.env` (gitignored). Default marker: `apps/ui/.default`.

## Everyday commands

```bash
ducker start | stop | restart
ducker status | stats | list
ducker shell
ducker upgrade                   # brew + re-apply config
ducker backup                    # config snapshot
ducker restore <backup-id>
```

## Makefile

From the repo directory, `make` targets match `ducker` (`ducker` calls Make under the hood):

```bash
make help
make install
make test
LIVE=1 make test
```

## Wipe / reinstall

```bash
ducker vm-uninstall              # delete Lima VM only (keeps ~/.lima/_config)
ducker lab-uninstall             # VM + managed host shell/CLI config
CONFIRM=yes ducker nuke          # full wipe including ~/.lima, brew packages, caches
ducker install                   # fresh lab
```

`ducker nuke` removes the entire `~/.lima` directory (all Lima instances plus `_config` / `_networks`). Use `vm-uninstall` if you only want the `docker` instance gone.

## Sources of truth

| Path | Role |
| --- | --- |
| `Brewfile` | Host packages |
| `lima-docker.yaml` | Lima template (Debian 13 + Docker) |
| `config/daemon.json` | Guest rootless dockerd |
| `config/profiles/` | `small` / `balanced` / `power` |
| `apps/ui/<provider>/` | Optional UIs |

Next: [Architecture](architecture.md) · [Troubleshooting](troubleshooting.md)
