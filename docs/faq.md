# FAQ

## Is this a Docker Desktop replacement?

It gives you Docker on a Mac without Desktop: a real Debian VM on Apple’s native Virtualization framework (`vz`), rootless Engine, and the `ducker` CLI. Because it uses `vz` (not a heavy hypervisor stack), it’s easier on CPU and RAM when you pick a sensible profile. Think of it as a small local lab you can version in git — not “Desktop, but free.”

## Do I need Docker Desktop installed?

No. Quit or uninstall Desktop if it fights over `/var/run/docker.sock`. This lab points `DOCKER_HOST` at Lima’s socket.

## Why Debian instead of Ubuntu?

We wanted a guest OS that matches how a lot of Linux/Kubernetes labs look. Lima’s stock `template://docker` is Ubuntu; we ship Debian on purpose.

## Can I shrink the 200 GiB disk?

Yes — before you create the VM:

```bash
ducker profile small       # 60 GiB
# or edit lima-docker.yaml, then ducker lima
```

Changing disk size after create usually means delete the instance and make a new one.

## Does `ducker install` include a UI?

No. Install a UI only if you want one: `ducker ui install`.

## How do I update Lima / Docker?

```bash
ducker upgrade
```

That upgrades the Homebrew packages, re-applies host config and the guest `daemon.json`, then runs verify.

## Is rootless “secure enough” for a local lab?

Rootless is the default and matches what Desktop/OrbStack do for local Docker. That does **not** mean it’s safe to expose the daemon to the internet.

## Will this become a Kubernetes installer?

That’s the plan — kind, Talos, GitOps tools behind the same `ducker` CLI. See [roadmap.md](roadmap.md).

## Where does the global CLI get linked?

```bash
ducker cli-install
# → ~/.local/bin/ducker or /usr/local/bin/ducker
```

## License?

MIT — see `LICENSE`.
