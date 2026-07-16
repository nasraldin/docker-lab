# Docs site

Docs are built with [MkDocs Material](https://squidfunk.github.io/mkdocs-material/) and published on GitHub Pages:

**https://nasraldin.github.io/docker-lab/**

Markdown lives in `docs/`. Site config is `mkdocs.yml`.

## Preview locally

From the repo root:

```bash
python3 -m venv .venv-docs
source .venv-docs/bin/activate
pip install -r requirements-docs.txt
make docs-serve
```

Open **http://127.0.0.1:8000**. It reloads when you edit files under `docs/`.

### Build only

```bash
make docs-build
```

Output goes to `./site/` (gitignored). CI uses the same command with `--strict`.

### Notes

- Use a venv (`.venv-docs/`) — Homebrew Python on macOS is externally managed.
- If `mkdocs` is already on your `PATH`, Make will use it; otherwise it prefers `.venv-docs/bin/mkdocs`.
- Diagram PNGs live in `docs/assets/diagrams/`. Regenerate with `make docs-diagrams` (needs `rsvg-convert` from `librsvg`).

## Publish (GitHub Pages)

On every push to `main` that touches docs, [`.github/workflows/docs.yml`](https://github.com/nasraldin/docker-lab/blob/main/.github/workflows/docs.yml) builds and deploys.

### One-time setup

1. Repo **Settings → Pages**
2. **Build and deployment → Source:** GitHub Actions
3. Push to `main`, or run **Actions → Docs → Run workflow**

PRs that change docs run `mkdocs build --strict` but do **not** deploy.
