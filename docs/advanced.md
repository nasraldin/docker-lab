# Advanced

## Manual setup (for understanding or debugging)

Normal path: `ducker install`. The steps below are roughly what the scripts do.

### 1. Host tools

```bash
brew install lima docker docker-compose docker-buildx yq jq
```

Optional: `lima-additional-guestagents` only if the guest arch isn’t native. Skip that for `aarch64` Debian on Apple Silicon.

Wire plugins in `~/.docker/config.json`:

```json
{
  "cliPluginsExtraDirs": ["/opt/homebrew/lib/docker/cli-plugins"]
}
```

### 2. Start Lima

```bash
limactl start --name=docker /path/to/lima-docker.yaml
```

First boot downloads the Debian cloud image and grows the disk — give it a few minutes.

### 3. Shell env

```bash
export DOCKER_HOST=unix://${HOME}/.lima/docker/sock/docker.sock
unset DOCKER_CONTEXT
```

### 4. Guest daemon

See [docker-daemon.md](docker-daemon.md), or just run `ducker daemon`.

## Upgrade

```bash
ducker upgrade
```

What that does:

1. Upgrade Lima + Docker CLI packages via Homebrew
2. Re-apply host CLI + shell config
3. Re-apply guest `daemon.json` and restart user Docker
4. Run `ducker verify`

## Backup / restore

```bash
ducker backup                 # under ~/.local/share/docker-lab/backups/<id>/
ducker backup --vm            # also stops VM and archives ~/.lima/docker (large)
ducker restore <id>
ducker restore <id> --vm
```

A normal backup includes:

- Active profile marker
- Copies of `lima-docker.yaml`, `config/daemon.json`, `config.env`
- Host `~/.docker/config.json` (if present)
- The managed bit of `~/.zshrc`

`--vm` archives the Lima instance directory (VM is stopped first). Restore carefully — it replaces the instance.

## Changing profile after first create

Editing CPU/memory/disk in the template does **not** resize a live VM. Typical flow:

```bash
ducker backup
ducker profile balanced
ducker vm-uninstall
ducker lima                 # create with new sizes
ducker daemon
ducker verify
```

## Sync home template

```bash
ducker sync-home-template   # cp lima-docker.yaml → ~/lima-docker.yaml
```

## Learning path

```text
Linux → Docker → containerd → Compose → (later) Kind via ducker / kube elsewhere
```

Keep heavy Kubernetes learning on dedicated nodes when you can. This Mac lab is mainly for Docker-first workflows.
