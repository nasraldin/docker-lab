# Comparison

Docker Lab vs common macOS Docker products:

| Feature | Docker Desktop | OrbStack | Docker Lab |
| --- | --- | --- | --- |
| Open source | ❌ | ❌ | ✅ |
| Debian guest | ❌ | ❌ | ✅ |
| Rootless Docker | ✅ | ✅ | ✅ |
| Custom daemon.json | Limited | Partial | ✅ |
| GitOps-ready config | ❌ | ❌ | ✅ |
| Platform Engineering focus | ❌ | ❌ | ✅ |
| One product CLI (`ducker`) | N/A | Partial | ✅ |
| Optional self-hosted UIs | Built-in | Built-in | Arcane / Dockhand |
| License cost | Paid (teams) | Paid (pro) | MIT |

## When to choose Docker Lab

- You want **Debian + rootless Engine** you fully control
- You treat local infra as **code** (Brewfile, Lima YAML, daemon.json, Make/`ducker`)
- You’re building habits toward **Kubernetes / GitOps / Platform Engineering**
- You prefer open source and no Desktop license

## When another tool may fit better

- You need a polished GUI-first experience with zero YAML
- You want the absolute simplest “just works” click-install for non-engineers

Those are valid — Docker Lab optimizes for **operators and platform engineers**, not for hiding the Linux underneath.
