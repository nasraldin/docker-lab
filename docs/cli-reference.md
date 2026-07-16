# CLI reference

Complete `ducker` command guide with **simulated terminal sessions** (command + typical output).

Outputs are representative of a healthy Apple Silicon lab after `ducker install`. Exact versions, paths, and timings vary by machine.

!!! tip "How to read sessions"
    Lines starting with `$` are what you type. Everything below is example output.
    Destructive commands are marked with a warning.

## Command map

| Command | Purpose |
| --- | --- |
| [`help`](#ducker-help) | Show usage |
| [`version`](#ducker-version) | Short version string |
| [`about`](#ducker-about) | Project + runtime info card |
| [`cli-install`](#ducker-cli-install) | Link `ducker` on your `PATH` |
| [`cli-uninstall`](#ducker-cli-uninstall) | Remove global symlink |
| [`install`](#ducker-install) | One-shot full lab setup |
| [`deps`](#ducker-deps--config--lima--daemon) | Re-run Homebrew packages |
| [`config`](#ducker-deps--config--lima--daemon) | Host CLI + `DOCKER_HOST` |
| [`lima`](#ducker-deps--config--lima--daemon) | Create/start Lima VM |
| [`daemon`](#ducker-deps--config--lima--daemon) | Apply guest `daemon.json` |
| [`profile`](#ducker-profile) | VM size: small / balanced / power |
| [`verify`](#ducker-verify) | Health checks |
| [`doctor`](#ducker-doctor) | Status + verify (+ `--fix`) |
| [`diagnose`](#ducker-diagnose) | Deep diagnostics dump |
| [`test`](#ducker-test--self-test) | Project self-test |
| [`self-test`](#ducker-test--self-test) | Alias for `test` |
| [`test-run`](#ducker-test-run) | alpine + stress-ng smoke |
| [`benchmark`](#ducker-benchmark) | Disk / pull / run timings |
| [`start`](#ducker-start--stop--restart) | Start Lima VM |
| [`stop`](#ducker-start--stop--restart) | Stop Lima VM |
| [`restart`](#ducker-start--stop--restart) | Restart Lima VM |
| [`status`](#ducker-status--list) | VM + Docker summary |
| [`list`](#ducker-status--list) | Alias for `status` |
| [`stats`](#ducker-stats) | Live Docker stats |
| [`shell`](#ducker-shell) | Shell into Debian guest |
| [`upgrade`](#ducker-upgrade) | Brew upgrade + re-apply config |
| [`backup`](#ducker-backup) | Snapshot lab config |
| [`restore`](#ducker-restore) | Restore a backup |
| [`ui`](#ducker-ui) | Optional Docker UIs |
| [`vm-uninstall`](#ducker-vm-uninstall) | Delete Lima VM only |
| [`lab-uninstall`](#ducker-lab-uninstall) | VM + managed host config |
| [`nuke`](#ducker-nuke) | Full wipe |

---

## Help & info

### `ducker help`

**What it does:** Prints the full command list and examples.

**When to use:** Anytime you forget a subcommand.

```console
$ ducker help
ducker — Docker Lab CLI (macOS + Lima + Docker)

Usage:
  ducker <command> [args...]

Setup:
  install                 Full lab: deps + config + lima + daemon + verify
  deps|config|lima|daemon Re-run one install piece
  profile <name>          VM size: small | balanced | power | list | show
  verify                  Health checks
  doctor [--fix]         status + verify (optional common repairs)
  ...
```

Also accepted: `ducker -h`, `ducker --help`.

---

### `ducker version`

**What it does:** Short version + CLI / lab paths (no emoji card).

**When to use:** Scripts, support tickets, quick checks.

```console
$ ducker version
Docker Lab v1.0.0
CLI:  /Users/you/.local/bin/ducker
Lab:  /Users/you/homelab/docker-lab
```

---

### `ducker about`

**What it does:** Rich info card — author, version, paths, Lima/Docker runtime, profile, UI default.

**When to use:** First thing after install; debugging “which lab am I talking to?”

```console
$ ducker about
🐳 Docker Lab
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

  Author      Nasr Aldin
  Website     https://nasraldin.com

  Version     1.0.0
  Tagline     Production-grade local Platform Engineering for Apple Silicon
  CLI path    /Users/you/.local/bin/ducker
  Global      /Users/you/.local/bin/ducker -> /Users/you/homelab/docker-lab/ducker
  Lab root    /Users/you/homelab/docker-lab
  Makefile    /Users/you/homelab/docker-lab/Makefile
  Template    /Users/you/homelab/docker-lab/lima-docker.yaml
  Config      /Users/you/homelab/docker-lab/config.env
  Daemon JSON /Users/you/homelab/docker-lab/config/daemon.json
  Profile     balanced

  Runtime     Lima 2.1.4 (instance docker: Running)
  Docker      Docker version 29.x.x (engine 29.x.x via Lima)
  Platform    Apple M1 Max
  Memory      64 GB
  DOCKER_HOST unix:///Users/you/.lima/docker/sock/docker.sock
  UI default  dockhand

  Features    lima · vz · virtiofs · rosetta · rootless · buildx · compose · profiles · multi-UI

  Commands    40 available — run: ducker help

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Local platform engineering lab — not Docker Desktop.
```

---

### `ducker cli-install`

**What it does:** Symlinks this repo’s `ducker` into `~/.local/bin` or `/usr/local/bin` so you can run it from any directory.

**When to use:** After cloning; after moving the repo.

```console
$ ./ducker cli-install
==> Linked /Users/you/.local/bin/ducker -> /Users/you/homelab/docker-lab/ducker
==> Try: ducker help
🐳 Docker Lab
...
```

!!! note
    Ensure `~/.local/bin` is on your `PATH`. If not, add:
    `export PATH="$HOME/.local/bin:$PATH"` to `~/.zshrc`.

---

### `ducker cli-uninstall`

**What it does:** Removes the global `ducker` symlink (does **not** delete the lab or VM).

```console
$ ducker cli-uninstall
==> Removed /Users/you/.local/bin/ducker
```

---

## Setup

### `ducker install`

**What it does:** Idempotent one-shot: `deps` → `config` → `lima` → `daemon` → `verify`.  
Does **not** install a UI (keep that opt-in).

**When to use:** Fresh Mac, or re-run after nuking.

```console
$ ducker install
==> Installing Homebrew packages from Brewfile
==> Merging Docker CLI plugins into ~/.docker/config.json
==> Installing DOCKER_HOST block into ~/.zshrc
==> Creating Lima instance 'docker' from lima-docker.yaml
...
==> Applying guest daemon.json
==> Verifying host tools
  [OK]   limactl present
  [OK]   docker present
  ...
==> All checks passed
Client 29.x.x / Server 29.x.x
OS=Debian GNU/Linux 13 (trixie) Arch=aarch64
```

First boot downloads the Debian image and expands the disk — expect several minutes.

---

### `ducker deps` / `config` / `lima` / `daemon`

**What they do:** Re-run one piece of install after you change something.

| Command | Re-runs |
| --- | --- |
| `ducker deps` | Homebrew `Brewfile` |
| `ducker config` | Host CLI plugins + `DOCKER_HOST` in `~/.zshrc` |
| `ducker lima` | Create/start VM from `lima-docker.yaml` |
| `ducker daemon` | Guest rootless `daemon.json` + restart Docker |

```console
$ ducker daemon
==> Applying guest rootless daemon.json
==> Restarting user Docker
==> Done
```

```console
$ ducker lima
==> Instance 'docker' already exists — starting
...
```

---

### `ducker profile`

**What it does:** Lists or applies VM resource profiles (`cpus` / `memory` / `disk` in `lima-docker.yaml`).

| Profile | CPUs | Memory | Disk |
| --- | --- | --- | --- |
| `small` | 4 | 8 GiB | 60 GiB |
| `balanced` | 6 | 16 GiB | 120 GiB |
| `power` | 8 | 24 GiB | 200 GiB |

**When to use:** Before first create, or before recreating the VM on a smaller Mac.

```console
$ ducker profile list
NAME       CPUS   MEMORY   DISK     DESCRIPTION
----       ----   ------   ----     -----------
balanced   6      16GiB    120GiB   Day-to-day Compose and builds
power      8      24GiB    200GiB   Default — heavy builds and long-running services
small      4      8GiB     60GiB    Laptops with limited RAM

Active: (none — lima-docker.yaml defaults / power-class)
```

```console
$ ducker profile balanced
==> Applying profile 'balanced' → .../lima-docker.yaml
==> Active profile set to 'balanced'
WARN: Instance 'docker' already exists — CPU/memory/disk changes need recreate:
  ducker backup && ducker vm-uninstall && ducker lima && ducker daemon && ducker verify
```

```console
$ ducker profile show
Active profile: balanced
  CPUs:    6
  Memory:  16GiB
  Disk:    120GiB
  ...
```

---

## Diagnostics & validation

### `ducker verify`

**What it does:** Host tools, Lima instance, Docker Engine, snapshotter, rootless, buildx, `hello-world`.

**When to use:** After install, after upgrade, before filing a bug.

```console
$ ducker verify
==> Verifying host tools
  [OK]   limactl present
  [OK]   docker present
  [OK]   docker compose plugin
  [OK]   docker buildx plugin
  [OK]   cliPluginsExtraDirs configured
==> Verifying Lima instance 'docker'
  [OK]   instance exists
  [OK]   instance Running
  [OK]   guest arch aarch64
==> Verifying Docker Engine via DOCKER_HOST=unix:///Users/you/.lima/docker/sock/docker.sock
  [OK]   docker server reachable
  [OK]   storage uses containerd snapshotter
  [OK]   rootless security option
  [OK]   buildx default builder healthy
  [OK]   hello-world
==> All checks passed
Client 29.0.0 / Server 29.0.0
OS=Debian GNU/Linux 13 (trixie) Arch=aarch64
```

---

### `ducker doctor`

**What it does:** Runs `status` then `verify`. With `--fix`, reapplies host config, force-restarts a stuck VM, and reapplies guest daemon.json.

**When to use:** First response to “Docker feels broken.”

```console
$ ducker doctor
==> Doctor — status
NAME      STATUS     ...
docker    Running    ...

Server=29.0.0 OS=Debian GNU/Linux 13 (trixie) Arch=aarch64

==> Doctor — verify
  [OK]   limactl present
  ...
==> Doctor: healthy
```

```console
$ ducker doctor --fix
==> Doctor — status
...
==> Doctor --fix: applying common repairs
==> Merging Docker CLI plugins...
==> Installing DOCKER_HOST block...
==> Applying guest daemon.json...
==> Doctor — verify
==> Doctor: healthy
```

---

### `ducker diagnose`

**What it does:** Verbose dump — host tools, Lima list, Docker info/context/buildx, profile, hostagent log tail, next-step hints.

**When to use:** Before opening an issue; paste relevant sections into the bug report.

```console
$ ducker diagnose

==> Host
  uname:     Darwin arm64
  brew:      /opt/homebrew
  limactl:   limactl version 2.1.4
  docker:    Docker version 29.0.0
  DOCKER_HOST=unix:///Users/you/.lima/docker/sock/docker.sock
  DOCKER_CONTEXT=<unset>

==> Lima
NAME      STATUS     CPUS  MEMORY   DISK     DIR
docker    Running    6     16GiB    120GiB   ~/.lima/docker
  status: Running

==> Docker
  Server=29.0.0 OS=Debian GNU/Linux 13 (trixie) Arch=aarch64 Rootless=[...]
  ...

==> Hints
  ducker doctor --fix
  ducker verify
  docs/troubleshooting.md
```

---

### `ducker test` / `self-test`

**What it does:** Project self-test (static by default). Set `LIVE=1` to also hit a Running VM.

**When to use:** Before release; after changing scripts/Makefile.

```console
$ ducker test

==> Static: required files
  [PASS] exists docker-lab/Makefile
  ...
==> Results: 89 passed, 0 failed
==> All tests passed
==> Tip: run LIVE=1 make test after `make install` for full runtime validation
```

```console
$ LIVE=1 ducker test
...
==> Live checks (LIVE=1)
  [PASS] instance docker is Running
  [PASS] scripts/verify.sh
  [PASS] docker run hello-world
==> Results: 95 passed, 0 failed
```

`ducker self-test` is the same as `ducker test`.

---

### `ducker test-run`

**What it does:** Quick smoke: `alpine uname` + short `stress-ng` run (needs Running VM).

```console
$ ducker test-run
Linux ... aarch64 GNU/Linux
...
```

---

### `ducker benchmark`

**What it does:** Times guest disk write, `docker pull alpine`, `hello-world`, and a short stress-ng run.

**When to use:** Compare profiles; baseline before/after upgrades.

```console
$ ducker benchmark
==> Docker Lab benchmark (instance=docker)

  · guest disk write (dd 256M) ... OK (412 ms)
  · docker pull alpine:latest ... OK (1830 ms)
  · docker run hello-world ... OK (620 ms)
  · stress-ng cpu 2 / 10s ... OK (10450 ms)

==> Benchmark complete
```

---

## Day-to-day lifecycle

### `ducker start` / `stop` / `restart`

**What they do:** Lima VM lifecycle for the `docker` instance.

```console
$ ducker start
...
$ ducker stop
$ ducker restart
```

---

### `ducker status` / `list`

**What it does:** `limactl list` + short Docker server line.

```console
$ ducker status
NAME      STATUS     CPUS  MEMORY   DISK     DIR
docker    Running    6     16GiB    120GiB   ~/.lima/docker

Server=29.0.0 OS=Debian GNU/Linux 13 (trixie) Arch=aarch64
```

`ducker list` (and `ducker ls`) are aliases for `status`.

---

### `ducker stats`

**What it does:** Guest CPU/mem/disk summary + `docker stats` (Ctrl+C to quit if streaming).

```console
$ ducker stats
==> Lima
NAME      STATUS     ...
docker    Running    ...

Guest: aarch64 cpus=6
               total        used        free
Mem:            15Gi       2.1Gi        12Gi
/dev/...        118G        14G        98G  13%

==> Docker stats (Ctrl+C to quit)
CONTAINER ID   NAME      CPU %     MEM USAGE / LIMIT
...
```

---

### `ducker shell`

**What it does:** Interactive shell inside the Debian guest.

```console
$ ducker shell
you@lima-docker:~$ uname -m
aarch64
you@lima-docker:~$ exit
```

---

### `ducker upgrade`

**What it does:** `brew update` / Brewfile packages, re-apply host config + guest daemon, then `verify` if the VM is Running.

**When to use:** After Homebrew updates; periodic maintenance.

```console
$ ducker upgrade
==> Upgrading Homebrew packages from Brewfile
==> Re-applying host Docker CLI + shell config
==> Re-applying guest daemon.json
==> Verifying
==> All checks passed
==> Upgrade finished
```

`ducker update` is an alias for `upgrade`.

---

## Backup & restore

### `ducker backup`

**What it does:** Snapshots lab config under `~/.local/share/docker-lab/backups/<id>/`.  
Add `--vm` to also archive `~/.lima/docker` (large; stops the VM first).

```console
$ ducker backup
==> Backing up lab config → /Users/you/.local/share/docker-lab/backups/20260716-201500
==> Backup complete: 20260716-201500
==> Restore with: ducker restore 20260716-201500
```

```console
$ ducker backup list
ID                   CONTENTS
20260716-201500      config
20260716-203012      config+vm
```

```console
$ ducker backup --vm
==> Stopping instance before VM archive
==> Archiving ~/.lima/docker (this can be large)
==> Backup complete: 20260716-203012
```

---

### `ducker restore`

**What it does:** Restores config from a backup id. Add `--vm` only if that backup includes a VM archive.

```console
$ ducker restore 20260716-201500
==> Restoring config from .../20260716-201500
==> Config restored. Re-apply guest daemon if VM is running: ducker daemon
```

```console
$ ducker restore 20260716-203012 --vm
==> Restoring Lima instance archive
==> Start with: ducker start && ducker verify
```

---

## Optional UI

### `ducker ui`

**What it does:** Manage optional Docker UIs. Default provider when omitted: **dockhand**.

| Subcommand | Purpose |
| --- | --- |
| `ui list` | Providers + status |
| `ui install [provider]` | Install & start UI |
| `ui up` / `down` / `start` / `stop` | Compose lifecycle |
| `ui open [provider]` | Open in browser |
| `ui status [provider]` | Container status |
| `ui default <provider>` | Set default for bare commands |
| `ui uninstall [provider]` | Remove UI only (not the VM) |

```console
$ ducker ui list
PROVIDER     STATUS     DEFAULT  URL
dockhand     running    *        http://localhost:9090
arcane       stopped             http://localhost:3552
```

```console
$ ducker ui install
==> Installing UI provider: dockhand
==> Writing apps/ui/dockhand/.env
==> docker compose up -d
==> Default UI set to dockhand
==> Open: http://localhost:9090
```

```console
$ ducker ui install arcane
==> Installing UI provider: arcane
...
Current default: dockhand
Set default to "arcane"? [y/N] n
```

```console
$ ducker ui open
# opens http://localhost:9090 (default)
```

```console
$ ducker ui default dockhand
==> Default UI set to dockhand
```

```console
$ ducker ui uninstall arcane
==> Stopping and removing ui-arcane
==> Removed apps/ui/arcane stack
```

!!! note
    UI uninstall never deletes the Lima VM. Use `vm-uninstall` / `nuke` for that.

---

## Cleanup

### `ducker vm-uninstall`

**What it does:** Deletes the Lima `docker` instance only (brew packages and `~/.zshrc` block stay).

```console
$ ducker vm-uninstall
==> Pruning all Docker containers, images, volumes...
==> Stopping instance 'docker'
==> Deleting instance 'docker'
==> Cleanup mode 'instance' complete
```

---

### `ducker lab-uninstall`

**What it does:** VM + managed host shell/CLI config (`DOCKER_HOST` block, plugins entry).

```console
$ ducker lab-uninstall
==> Deleting instance...
==> Removing managed shell block from ~/.zshrc
==> Removing Homebrew cliPluginsExtraDirs entry
==> Cleanup mode 'host' complete
```

---

### `ducker nuke`

**What it does:** Full wipe — VM, **entire** `~/.lima`, Lima caches, managed host config, Brewfile formulae, UI local state, lab backups under `~/.local/share/docker-lab`.  
Does **not** delete this git repo.

!!! danger "Destructive"
    Prefer `CONFIRM=yes` in CI/scripts. Interactive terminals prompt for `yes`.

```console
$ CONFIRM=yes ducker nuke

WARNING: destructive full cleanup
This will remove:
  - Lima VM "docker" (...)
  - Entire /Users/you/.lima directory (...)
  - Lima download caches (~/Library/Caches/lima)
  - Managed DOCKER_HOST block in ~/.zshrc
  ...
==> CONFIRM=yes — proceeding without prompt
==> Nuking docker-lab stack...
==> Removing /Users/you/.lima
==> /Users/you/.lima removed
...
WARN: Full cleanup done. Reinstall with: cd ~/homelab/docker-lab && make install
==> Cleanup mode 'nuke' complete
```

Aliases: `ducker purge` → nuke; `ducker uninstall` → vm-uninstall.

---

## Typical workflows

### Fresh machine

```console
$ curl -fsSL https://raw.githubusercontent.com/nasraldin/docker-lab/main/install.sh | bash
$ ducker about
$ ducker verify
$ ducker ui install
$ ducker ui open
```

### Daily use

```console
$ ducker start
$ ducker status
$ docker compose up -d
$ ducker stop          # end of day
```

### Something broke

```console
$ ducker doctor --fix
$ ducker diagnose
$ ducker verify
```

### Before a release

```console
$ ducker test
$ LIVE=1 ducker test
$ ducker benchmark
$ ducker about
```

---

## Related

- [Installation](installation.md) — profiles, first boot
- [Troubleshooting](troubleshooting.md) — symptoms → fixes
- [Screenshots](screenshots/index.md) — PNG captures for releases
- [Homebrew](homebrew.md) — `brew install ducker-lab`
