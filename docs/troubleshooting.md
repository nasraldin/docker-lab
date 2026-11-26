# Troubleshooting

## Start here

```bash
ducker doctor
ducker doctor --fix
ducker diagnose
ducker verify
```

`ducker doctor --fix` tries the usual repairs (host tools, CLI plugins, `DOCKER_HOST`, Lima restart, guest `daemon.json`, buildx). Details: [CLI reference — doctor](cli-reference.md#ducker-doctor).

## Symptom → fix

| Symptom                                                          | Fix                                                                        |
| ---------------------------------------------------------------- | -------------------------------------------------------------------------- |
| `field images must be set`                                       | Use this repo’s `lima-docker.yaml` (it has `base:` / images)               |
| Instance `Stopped`, no disk                                      | `ducker doctor --fix`, or `limactl stop -f docker && limactl start docker` |
| `another hostagent may already be running`                       | `ducker doctor --fix`, or `limactl stop -f docker` then start              |
| `cliPluginsExtraDirs` in daemon.json → Docker won’t start        | `ducker doctor --fix` rewrites a known-good guest `daemon.json`            |
| buildx `default` error on `/var/run/docker.sock`                 | `ducker doctor --fix` (sets `DOCKER_HOST` + clears context)                |
| Compose/buildx “unknown command”                                 | `ducker doctor --fix` or `ducker deps`                                     |
| `docker-credential-osxkeychain`: executable file not found         | `ducker doctor --fix` or `brew install docker-credential-helper`           |
| Plugin `docker-sbom` not valid / broken Desktop symlinks         | `ducker doctor --fix` (removes Desktop plugin symlinks)                    |
| Docker unreachable but VM is Running                             | `ducker doctor --fix` (wait for socket + restart guest Docker)             |
| Harmless restart warning `127.0.0.1:5355 address already in use` | LLMNR collision — ignore unless you need that forward                      |
| `manifest.v1+prettyjws is no longer supported`                   | Image too old — pick a maintained one                                      |
| No Lima instance at all                                          | `ducker install` (doctor will not create one)                              |

## Private hostnames resolve to public addresses

Add site-specific hostname mappings to `${LIMA_HOME:-$HOME/.lima}/_config/override.yaml` on the Mac. This override applies to instances under that Lima home. Edit the existing `hostResolver.hosts` map when a hostname changes and start the affected VM again so its host agent loads the new entries. For example:

```yaml
hostResolver:
  hosts:
    registry.lab.example: 192.0.2.40
    packages.lab.example: 192.0.2.40
```

Verify both the instance settings and normal guest resolution:

```bash
limactl list -f '{{json .Config}}' docker | jq '.hostResolver.hosts'
limactl shell docker -- getent ahostsv4 registry.lab.example
limactl shell docker -- resolvectl dns
limactl shell docker -- resolvectl domain
```

If the effective config looks right but `getent` returns a public address, query the Lima resolver directly with `dig` in the guest. Use the address of the Lima DNS server from the preceding check. For a guest that reports `192.168.5.2` on its Lima link:

```bash
limactl shell docker -- dig +short @192.168.5.2 registry.lab.example A
```

Guests configured with split DNS may use public DNS by default and reserve the Lima resolver for a list of route-only domains. If the direct query returns the private address, add the private hostnames as route-only domains on the link already using Lima DNS. On a guest using systemd-networkd, `networkctl status eth0` shows the active network file. For an active file named `10-netplan-eth0.network`, add this drop-in inside the guest:

```ini
# /etc/systemd/network/10-netplan-eth0.network.d/60-lima-host-overrides.conf
[Network]
Domains=~registry.lab.example ~packages.lab.example
```

Keep the existing routing domains and public DNS settings. Reload the network configuration during an idle window, flush cached DNS answers, and check both a private hostname and a public hostname:

```bash
limactl shell docker -- sudo networkctl reload
limactl shell docker -- sudo resolvectl flush-caches
limactl shell docker -- getent ahostsv4 registry.lab.example
limactl shell docker -- getent ahostsv4 github.com
```

If a CI runner runs inside Docker, repeat the lookup inside a runner container with `docker exec <runner> getent ahostsv4 registry.lab.example`. Check the runner's online status in GitHub Actions separately.

See [Lima DNS](https://lima-vm.io/docs/config/network/user/#dns-19216853) and [systemd network DNS routing](https://www.freedesktop.org/software/systemd/man/latest/systemd.network.html#Domains=).

## Guest disk I/O errors with low macOS disk space

`ducker diagnose` shows free space on the macOS filesystem holding the Lima disk and
inside the guest. A sparse Lima disk can run out of backing storage on macOS even
when the guest reports free space. If guest commands fail with `Input/output error`,
free space on macOS before restarting Lima. Once the guest is accessible, run
`limactl shell docker -- sudo systemctl start fstrim.service` to return freed blocks
from the guest to the host.

`ducker lima` configures hourly trim on new and existing guests. `ducker daemon`
applies the default builder's 20 GB cache target and 30 GB guest free-space target
and restarts Docker. Run it when containers can be interrupted. The cache policy
can evict unused build cache. Running containers, images in use, volumes, and host
files have their own storage needs.

## Logs

```bash
# Host agent
tail -f ~/.lima/docker/ha.stderr.log

# Guest boot / cloud-init
limactl shell docker -- sudo tail -f /var/log/cloud-init-output.log

# Rootless docker
limactl shell docker -- journalctl --user -u docker -f
```

## Don’t do these

1. Don’t treat `~/.lima/<name>/lima.yaml` as your main template.
2. Don’t feed Lima 2.x a YAML with no `images` / `base`.
3. Don’t configure rootless Docker via `/etc/docker/daemon.json`.
4. Don’t force `"storage-driver": "overlay2"` when using the containerd snapshotter.
5. Don’t put host-only Docker CLI keys into guest `daemon.json`.
6. Don’t rely on `progrium/stress` on modern containerd.
7. Don’t create an extra buildx builder “just because” — default is fine.
8. Don’t give the VM almost all of the host’s RAM/CPU.

## Quick checklist

```bash
limactl list
limactl shell docker -- uname -m     # aarch64
docker run --rm hello-world
docker compose version
docker buildx ls
ducker verify
```
