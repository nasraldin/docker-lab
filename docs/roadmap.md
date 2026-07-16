# Roadmap

## Where we are

People often find this as a “Docker Desktop alternative.” Fair enough — it does that job.

The longer goal is simpler:

> A local Docker / platform lab on Apple Silicon you can install, check, and rebuild with one CLI (`ducker`).

## Near term (Docker Lab)

- [x] Idempotent `ducker install` + verify / doctor / test
- [x] Optional UIs (Arcane, Dockhand)
- [x] Docs + CI lint/test
- [x] `benchmark`, `upgrade`, `backup` / `restore`, profiles
- [x] CLI reference with sample command + output
- [x] Homebrew tap (`ducker-lab`) + release workflow
- [x] Broader `ducker doctor --fix`
- [ ] Real CLI/UI PNG screenshots refreshed each release
- [x] Diagram assets (install flow, stack, roadmap, release channels)

## Mid term (more labs behind the same CLI)

![Roadmap from Docker Lab toward Compose, Kind, Talos, Kubernetes, GitOps, Platform Lab](assets/diagrams/roadmap.png)

Rough shape we want:

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

Same habits everywhere: install → verify → doctor → upgrade → backup.

## Things that shouldn’t change

1. **Apple Silicon first**, including the traps we document
2. **Config as code** — no one-off snowflake VMs
3. **A validation story** — verify / doctor / test / benchmark
4. **What not to do** — teach the failure modes
5. Grow into a wider platform CLI, not stop at “Docker works”
