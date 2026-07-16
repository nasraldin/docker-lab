# Roadmap

## Identity

Today the project is often discovered as a “Docker Desktop alternative.”

The stronger identity:

> **A production-grade local Platform Engineering environment for Apple Silicon.**

One CLI — `ducker` — bootstraps the local platform stack.

## Near term (Docker Lab)

- [x] Idempotent `ducker install` + verify / doctor / test
- [x] Optional UIs (Arcane, Dockhand)
- [x] Docs split + CI lint/test
- [x] `benchmark`, `upgrade`, `backup` / `restore`, profiles
- [x] CLI reference with simulated command + output sessions
- [x] Homebrew tap (`ducker-lab`) + release workflow
- [ ] Screenshots (PNG) refreshed each release
- [ ] `ducker doctor --fix` coverage expansion

## Mid term (Developer Platform CLI)

```text
Docker Lab
  → Compose Lab
  → Kind Lab
  → Talos Lab
  → Kubernetes Lab
  → GitOps Lab
  → Platform Lab
```

Intended CLI shape:

```bash
ducker install docker
ducker install kind
ducker install talos
ducker install argocd
ducker install prometheus
ducker install grafana
ducker install harbor
ducker install vault
ducker install keycloak
```

Same product habits: install → verify → doctor → upgrade → backup.

## Principles that stay fixed

1. **Apple Silicon first**, documented traps included
2. **Config as code** — no snowflake VMs
3. **Validation story** — verify / doctor / test / benchmark
4. **What not to do** — teach failure modes
5. Grow into a **platform CLI**, not stop at “Docker works”
