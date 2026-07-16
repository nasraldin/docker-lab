# Screenshots

Visual PNGs for releases, plus a full **text** command gallery in the [CLI reference](../cli-reference.md).

## Prefer the CLI reference

For every `ducker` command with **purpose, usage, and simulated terminal output**, see:

**[CLI reference →](../cli-reference.md)**

That page is the source of truth for command documentation (like professional CLI product docs). This page tracks **PNG assets** to attach at release time.

## Required PNG shots

Capture on Apple Silicon after a clean `ducker install`:

| File | Command / view |
| --- | --- |
| `ducker-about.png` | `ducker about` |
| `ducker-doctor.png` | `ducker doctor` |
| `ducker-status.png` | `ducker status` |
| `ducker-benchmark.png` | `ducker benchmark` |
| `ducker-profile-list.png` | `ducker profile list` |
| `docker-ps.png` | `docker ps` (with a running container) |
| `ui-dockhand.png` | Dockhand UI (default — `ducker ui open`) |
| `ui-arcane.png` | Arcane UI in browser |

## Capture tips

```bash
ducker about
ducker doctor
ducker status
ducker benchmark
ducker profile list

docker run -d --name demo nginx:alpine
docker ps
ducker ui open
```

Store PNGs in this directory (`docs/screenshots/`). Keep them under ~500 KB each when possible.

## Placeholder

Until real captures are committed, use the [CLI reference](../cli-reference.md) simulated sessions. Do not commit fake marketing mockups that misrepresent the CLI.
