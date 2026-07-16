# Releasing

## Version source of truth

`config.env` → `DOCKER_LAB_VERSION` (shown by `ducker about` / `ducker version`).

## Docs site (GitHub Pages)

Published at: [https://nasraldin.github.io/docker-lab/](https://nasraldin.github.io/docker-lab/)

Built from `docs/` + `mkdocs.yml` by [`.github/workflows/docs.yml`](https://github.com/nasraldin/docker-lab/blob/main/.github/workflows/docs.yml).

For **local preview**, full steps, and Pages setup, see [Docs site](docs-site.md).

## Release checklist

1. Bump `DOCKER_LAB_VERSION` in `config.env`
2. Update changelog notes in the GitHub Release body
3. Ensure CI + Docs workflows are green on `main`
4. Tag and push:

```bash
git tag -a v1.0.0 -m "v1.0.0"
git push origin v1.0.0
```

5. Create a GitHub Release from the tag:

```bash
gh release create v1.0.0 --generate-notes
```

6. **Homebrew** — automated if `HOMEBREW_TAP_TOKEN` is set (see [Homebrew](homebrew.md)).  
   The release triggers `.github/workflows/homebrew.yml`, which updates `nasraldin/homebrew-tools`.
7. Smoke on a clean Mac:

```bash
brew tap nasraldin/tools && brew install ducker-lab
# or: curl -fsSL …/install.sh | bash
ducker about
ducker verify
```

## Distribution channels

```text
v1.0
  → GitHub Release
  → install.sh (curl | bash)
  → brew tap nasraldin/tools && brew install ducker-lab   # CI updates tap on release
  → Docs site (GitHub Pages)
```

## What CI validates

On every PR / push to `main`:

- ShellCheck + shfmt (scripts + `ducker` + `install.sh`)
- markdownlint + yamllint + actionlint
- `make test` (static; no live VM)
- Docs: `mkdocs build --strict` (PRs); deploy Pages on `main`

Live VM tests stay manual or on a self-hosted Mac runner (`LIVE=1 make test`).
