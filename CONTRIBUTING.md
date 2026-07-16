# Contributing

Thanks for helping with Docker Lab.

## Development

```bash
git clone https://github.com/nasraldin/docker-lab.git
cd docker-lab
make test                 # static checks (safe anytime)
LIVE=1 make test          # needs a Running Lima VM
```

### Docs

```bash
python3 -m venv .venv-docs
source .venv-docs/bin/activate
pip install -r requirements-docs.txt
make docs-serve           # http://127.0.0.1:8000
```

More: [Docs site](https://nasraldin.github.io/docker-lab/docs-site/).

### CLI changes

- Keep Make targets thin; put logic in `scripts/`
- Keep `ducker` as the public CLI
- Run `shfmt -w -i 2 -ci` and `shellcheck -x -e SC1090,SC1091,SC2016` on shell changes
- Update `scripts/test.sh` when you add required files or commands

### Homebrew

Formula name is **`ducker-lab`** (homebrew-core already has an unrelated `ducker`).  
Source: `Formula/ducker-lab.rb`. Tap: [`nasraldin/homebrew-tools`](https://github.com/nasraldin/homebrew-tools).  
See [Homebrew docs](https://nasraldin.github.io/docker-lab/homebrew/).

## Pull requests

1. Keep PRs focused
2. `make test` should pass
3. CI must be green (lint + static test; docs build when docs change)
4. Don’t commit secrets, `apps/ui/**/.env`, `site/`, or `.venv-docs/`

## Code of conduct

Be respectful. Document traps as carefully as features.
