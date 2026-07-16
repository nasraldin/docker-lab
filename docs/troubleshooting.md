# Troubleshooting

## Quick path

```bash
ducker doctor
ducker doctor --fix
ducker diagnose
ducker verify
```

`ducker doctor --fix` applies structured repairs (host tools, CLI plugins, `DOCKER_HOST`, Lima restart, guest `daemon.json`, buildx). See [CLI reference — doctor](cli-reference.md#ducker-doctor).

## Symptom → fix

| Symptom | Fix |
| --- | --- |
| `field images must be set` | Use this repo’s `lima-docker.yaml` (has `base:` / images) |
| Instance `Stopped`, no disk | `ducker doctor --fix` (force stop/start) or `limactl stop -f docker && limactl start docker` |
| `another hostagent may already be running` | `ducker doctor --fix` or `limactl stop -f docker` then start |
| `cliPluginsExtraDirs` in daemon.json → Docker won’t start | `ducker doctor --fix` re-applies known-good guest `daemon.json` |
| buildx `default` error on `/var/run/docker.sock` | `ducker doctor --fix` (sets `DOCKER_HOST` + clears context) |
| Compose/buildx “unknown command” | `ducker doctor --fix` (plugins + Brewfile) or `ducker deps` |
| Docker unreachable but VM Running | `ducker doctor --fix` (socket wait + guest docker restart) |
| Harmless restart warning `127.0.0.1:5355 address already in use` | LLMNR collision — ignore unless you need that forward |
| `manifest.v1+prettyjws is no longer supported` | Image too old — pick a maintained image |
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

## What **not** to do

1. Do **not** put custom templates under `~/.lima/<name>/lima.yaml` as the primary workflow.
2. Do **not** use bare Lima YAML without `images` / `base` on Lima 2.x.
3. Do **not** configure rootless Docker via `/etc/docker/daemon.json`.
4. Do **not** force `"storage-driver": "overlay2"` when using containerd snapshotter.
5. Do **not** put host-only Docker CLI keys into guest `daemon.json`.
6. Do **not** rely on `progrium/stress` on modern containerd.
7. Do **not** create an extra buildx builder “just because” — default is fine.
8. Do **not** give the VM nearly all host RAM/CPU.

## Validation checklist

```bash
limactl list
limactl shell docker -- uname -m     # aarch64
docker run --rm hello-world
docker compose version
docker buildx ls
ducker verify
```
