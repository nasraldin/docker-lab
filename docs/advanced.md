# Advanced

## Manual setup (understand / customize / debug)

Automated path: `ducker install`. The steps below match what the scripts do.

### 1. Host tools

```bash
brew install lima docker docker-compose docker-buildx yq jq
```

Optional: `lima-additional-guestagents` only for **non-native** guest architectures. Skip for native `aarch64` Debian on Apple Silicon.

Wire plugins in `~/.docker/config.json`:

```json
{
  "cliPluginsExtraDirs": [
    "/opt/homebrew/lib/docker/cli-plugins"
  ]
}
```

### 2. Start Lima

```bash
limactl start --name=docker /path/to/lima-docker.yaml
```

First boot downloads the Debian cloud image and expands the disk — expect several minutes.

### 3. Shell env

```bash
export DOCKER_HOST=unix://${HOME}/.lima/docker/sock/docker.sock
unset DOCKER_CONTEXT
```

### 4. Guest daemon

See [docker-daemon.md](docker-daemon.md). Or: `ducker daemon`.

## Upgrade

```bash
ducker upgrade
```

Safe sequence:

1. `brew bundle` / upgrade Lima + Docker CLI packages
2. Re-apply host CLI + shell config
3. Re-apply guest `daemon.json` and restart user Docker
4. `ducker verify`

## Backup / restore

```bash
ducker backup                 # writes under ~/.local/share/docker-lab/backups/<id>/
ducker backup --vm            # also stops VM and archives ~/.lima/docker (large)
ducker restore <id>
ducker restore <id> --vm
```

Backups always include:

- Active profile marker
- Copies of `lima-docker.yaml`, `config/daemon.json`, `config.env`
- Host `~/.docker/config.json` (if present)
- Managed `~/.zshrc` snippet (extracted)

`--vm` archives the Lima instance directory (stop first). Restore with care — it replaces the instance.

## Profiles after first create

Changing CPU/memory/disk in the template does **not** resize a live instance automatically. Typical flow:

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

## Homelab learning path

```text
Linux → Docker → containerd → Compose → (later) kubeadm on Proxmox / Kind via ducker
```

Keep heavy Kubernetes learning on dedicated nodes when possible; this Mac lab is for Docker-native Platform Engineering workflows first.
