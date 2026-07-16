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

| Symptom | Fix |
| --- | --- |
| `field images must be set` | Use this repo’s `lima-docker.yaml` (it has `base:` / images) |
| Instance `Stopped`, no disk | `ducker doctor --fix`, or `limactl stop -f docker && limactl start docker` |
| `another hostagent may already be running` | `ducker doctor --fix`, or `limactl stop -f docker` then start |
| `cliPluginsExtraDirs` in daemon.json → Docker won’t start | `ducker doctor --fix` rewrites a known-good guest `daemon.json` |
| buildx `default` error on `/var/run/docker.sock` | `ducker doctor --fix` (sets `DOCKER_HOST` + clears context) |
| Compose/buildx “unknown command” | `ducker doctor --fix` or `ducker deps` |
| Docker unreachable but VM is Running | `ducker doctor --fix` (wait for socket + restart guest Docker) |
| Harmless restart warning `127.0.0.1:5355 address already in use` | LLMNR collision — ignore unless you need that forward |
| `manifest.v1+prettyjws is no longer supported` | Image too old — pick a maintained one |
| No Lima instance at all | `ducker install` (doctor will not create one) |

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
