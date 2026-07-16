# Performance

## Mount strategy

Mac bind mounts (VirtioFS) are convenient but expensive for chatty trees.

Prefer **named volumes** for:

- `node_modules`
- `.next`
- package caches
- databases

```yaml
services:
  app:
    volumes:
      - .:/app
      - node_modules:/app/node_modules
volumes:
  node_modules:
```

## Benchmark

Measure a baseline after install:

```bash
ducker benchmark
```

Reports approximate timings for:

1. Guest disk write (dd inside Lima)
2. Image pull (`alpine`)
3. Container start (`hello-world`)
4. Optional short CPU stress (`stress-ng`)

Use results to compare profiles (`small` vs `power`) or before/after upgrades.

## Load test image

`progrium/stress` uses obsolete manifest v1 and **fails** on containerd v2.1+. Use stress-ng:

```bash
ducker test-run
# or:
docker run --rm ghcr.io/colinianking/stress-ng \
  --cpu 4 --vm 2 --vm-bytes 1G --timeout 30s --metrics-brief
```

Healthy signs: `failed: 0`, no OOM. The `sched_autogroup_enabled` note is optional/benchmark-only.

## Resource headroom

Leave CPU/RAM for macOS. If the host feels sluggish:

```bash
ducker profile balanced   # or small
# recreate VM after profile change — see advanced.md
```

## Stats

```bash
ducker stats              # docker stats + Lima summary
```
