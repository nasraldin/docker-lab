# Docs site

The project docs are built with [MkDocs Material](https://squidfunk.github.io/mkdocs-material/) and published to GitHub Pages:

**https://nasraldin.github.io/docker-lab/**

Source files live in `docs/` at the repo root. Site config is `mkdocs.yml`.

## Preview locally

From the repo root:

```bash
python3 -m venv .venv-docs
source .venv-docs/bin/activate
pip install -r requirements-docs.txt
make docs-serve
```

Open **http://127.0.0.1:8000** — the site reloads when you edit markdown under `docs/`.

### Build only (no server)

```bash
make docs-build
```

Output goes to `./site/` (gitignored). CI uses the same command with `--strict`.

### Notes

- Prefer a venv (`.venv-docs/`) — Homebrew Python is externally managed on macOS.
- If `mkdocs` is already on your `PATH`, `make docs-serve` / `make docs-build` will use it; otherwise they prefer `.venv-docs/bin/mkdocs`.

## Publish (GitHub Pages)

On every push to `main` that touches docs, [`.github/workflows/docs.yml`](https://github.com/nasraldin/docker-lab/blob/main/.github/workflows/docs.yml) builds and deploys the site.

### One-time repo setup

1. Repo **Settings → Pages**
2. **Build and deployment → Source:** GitHub Actions
3. Push to `main`, or run **Actions → Docs → Run workflow**

Pull requests that change docs run `mkdocs build --strict` but do **not** deploy.
