# Docker UI providers

> Lab self-test: from repo root run `make test` (add `LIVE=1` when the VM is up).

Choose a UI at install time. Commands:

```bash
make ui list
make ui install arcane      # or: make ui install dockhand
make ui up                  # uses default provider
make ui open dockhand       # explicit provider
make ui default dockhand    # set default
make ui uninstall arcane
```

| Provider   | Port | First login                                      |
| ---------- | ---- | ------------------------------------------------ |
| `arcane`   | 3552 | `arcane` / `arcane-admin` (change on first login) |
| `dockhand` | 9090 | first-run wizard creates admin                   |

Default selection is stored in `apps/ui/.default` (gitignored).
