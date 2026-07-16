# Comparison

How Docker Lab stacks up against the usual Mac Docker options:

| | Docker Desktop | OrbStack | Docker Lab |
| --- | --- | --- | --- |
| Open source | No | No | Yes |
| Debian guest | No | No | Yes |
| Rootless Docker | Yes | Yes | Yes |
| Full control of `daemon.json` | Limited | Partial | Yes |
| Config in the repo (Brewfile, Lima, daemon) | No | No | Yes |
| CLI for install / verify / doctor | N/A | Partial | `ducker` |
| Built-in UI | Yes | Yes | Optional (Dockhand / Arcane) |
| Cost | Paid for teams | Paid for Pro | MIT |

## Pick Docker Lab if…

- You want Debian + rootless Engine on native Apple `vz` (lighter host impact) and you want to own the config files
- You’re fine with a little YAML and a CLI
- You’re heading toward Kubernetes / GitOps-style local labs later

## Pick something else if…

- You want a polished GUI and almost no terminal
- You need the simplest click-install for people who won’t touch Lima YAML

That’s fine — this project is aimed at people who want to see and control the Linux underneath.
