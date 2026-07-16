# Screenshots

Visual proof helps people trust the project. Capture these on Apple Silicon after a clean `ducker install` and attach PNGs here before each release.

## Required shots

| File | Command / view |
| --- | --- |
| `ducker-about.png` | `ducker about` |
| `ducker-doctor.png` | `ducker doctor` |
| `ducker-status.png` | `ducker status` |
| `ducker-benchmark.png` | `ducker benchmark` |
| `docker-ps.png` | `docker ps` (with a running container) |
| `ui-dockhand.png` | Dockhand UI (default — `ducker ui open`) |
| `ui-arcane.png` | Arcane UI in browser |

## Capture tips

```bash
# Terminal (macOS Screenshot → select window, or):
ducker about
ducker doctor
ducker status
ducker benchmark

docker run -d --name demo nginx:alpine
docker ps
```

Store PNGs in this directory (`docs/screenshots/`). Keep them under ~500 KB each when possible.

## Placeholder

Until real captures are committed, this page documents what to add. Do not commit fake marketing mockups that misrepresent the CLI.
