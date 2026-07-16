# Performance

## Mounts

Mac bind mounts over VirtioFS are handy, but chatty trees get slow.

Prefer **named volumes** for things like:

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

After install, get a rough baseline:

```bash
ducker benchmark
```

It times:

1. Guest disk write (`dd` inside Lima)
2. Image pull (`alpine`)
3. Container start (`hello-world`)
4. Optional short CPU stress (`stress-ng`)

Useful for comparing profiles (`small` vs `power`) or before/after upgrades.

## Load test image

`progrium/stress` uses an old manifest and **fails** on containerd v2.1+. Use stress-ng:

```bash
ducker test-run
# or:
docker run --rm ghcr.io/colinianking/stress-ng \
  --cpu 4 --vm 2 --vm-bytes 1G --timeout 30s --metrics-brief
```

Healthy: `failed: 0`, no OOM. The `sched_autogroup_enabled` note is optional and only matters for benchmarks.

## Leave room for macOS

If the Mac feels sluggish:

```bash
ducker profile balanced   # or small
# recreate the VM after a profile change — see advanced.md
```

## Stats

```bash
ducker stats              # docker stats + Lima summary
```
