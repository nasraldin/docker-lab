# FAQ

## Is this a Docker Desktop replacement?

It replaces the **developer experience** of running Docker on a Mac: a real Linux VM, rootless Engine, and a product-style CLI (`ducker`). Marketing-wise we position it as a **local Platform Engineering environment**, not “Desktop but free.”

## Do I need Docker Desktop installed?

No. Uninstall or quit Desktop if it fights over `/var/run/docker.sock`. This lab uses `DOCKER_HOST` → Lima’s socket.

## Why Debian instead of Ubuntu?

Aligned with typical Linux/Kubernetes labs and a clear, reproducible guest OS. The official Lima `template://docker` path uses Ubuntu LTS; we intentionally diverge.

## Can I shrink the 200 GiB disk?

Yes — before first create:

```bash
ducker profile small       # 60 GiB
# or edit lima-docker.yaml disk: then ducker lima
```

Changing disk after create usually means delete + recreate the instance.

## Does `ducker install` include a UI?

No. UIs are opt-in: `ducker ui install`.

## How do I update Lima / Docker?

```bash
ducker upgrade
```

That upgrades Homebrew packages, re-applies host config and guest daemon.json, then verifies.

## Is rootless secure enough for local labs?

Rootless is the default and matches modern Desktop/OrbStack practice. Do not confuse “rootless in the guest” with “safe to expose docks to the internet.”

## Will this become a Kubernetes installer?

That’s the roadmap — Kind, Talos, GitOps tools behind the same `ducker` CLI. See [roadmap.md](roadmap.md).

## Where is the global CLI linked?

```bash
ducker cli-install
# → ~/.local/bin/ducker or /usr/local/bin/ducker
```

## License?

MIT — see `LICENSE`.
