# Docker UI providers

> Lab self-test: from repo root run `make test` (add `LIVE=1` when the VM is up).

Choose a UI at install time. Commands:

```bash
make ui list
make ui install dockhand    # or: make ui install (same — dockhand is default)
make ui install arcane
make ui up                  # uses default provider
make ui open arcane         # explicit provider
make ui default dockhand    # set default
make ui uninstall arcane
```

| Provider   | Port | First login                                       |
| ---------- | ---- | ------------------------------------------------- |
| `dockhand` | 9090 | first-run wizard creates admin                    |
| `arcane`   | 3552 | `arcane` / `arcane-admin` (change on first login) |

Default selection is stored in `apps/ui/.default` (gitignored).
