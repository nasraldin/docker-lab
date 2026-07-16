# Homebrew

`ducker` (the CLI) is distributed via a **custom Homebrew tap** as formula **`ducker-lab`**.

```bash
brew tap nasraldin/tools
brew install ducker-lab
ducker version    # CLI name stays `ducker`
```

Why not `brew install ducker`? **homebrew-core already has an unrelated formula** named [`ducker`](https://formulae.brew.sh/formula/ducker) (a Docker TUI). Our package is `ducker-lab` to avoid that clash.

Under the hood the tap is **[`nasraldin/homebrew-tools`](https://github.com/nasraldin/homebrew-tools)**  
(`brew tap user/name` → repo `user/homebrew-name`).

---

## Status

| Piece | Status |
| --- | --- |
| Formula source in docker-lab | ✅ `Formula/ducker-lab.rb` |
| Tap repo [`nasraldin/homebrew-tools`](https://github.com/nasraldin/homebrew-tools) | ✅ created |
| Local clone (recommended) | `~/homelab/taps/homebrew-tools` |
| Auto-update formula on GitHub Release | ✅ workflow (needs `HOMEBREW_TAP_TOKEN`) |
| Official Homebrew core | ❌ not used (custom tap only) |

**Remaining once:** add the `HOMEBREW_TAP_TOKEN` secret on docker-lab.  
**After that:** publish a GitHub Release → CI pushes an updated formula into the tap.

---

## Local clone of the tap

The tap is a **separate git repo**. Keep it next to docker-lab under `taps/`:

```bash
mkdir -p ~/homelab/taps
cd ~/homelab/taps
git clone https://github.com/nasraldin/homebrew-tools.git
cd homebrew-tools
```

Layout:

```text
~/homelab/
  docker-lab/              # this project
  taps/
    homebrew-tools/        # brew tap clone (separate git remote)
```

Sync the formula from docker-lab into the tap (before the first automated release, or when editing locally):

```bash
cp ~/homelab/docker-lab/Formula/ducker-lab.rb \
   ~/homelab/taps/homebrew-tools/Formula/ducker-lab.rb
rm -f ~/homelab/taps/homebrew-tools/Formula/ducker.rb   # legacy name — do not keep

cd ~/homelab/taps/homebrew-tools
git add Formula/ducker-lab.rb
git add -u Formula/ducker.rb
git commit -m "ducker-lab: sync formula from docker-lab"
git push origin main
```

> Moving folders on disk does **not** update GitHub. Always `git commit` + `git push` in `homebrew-tools` (or let the release workflow do it).

---

## CI secret (required for auto-publish)

The docker-lab release workflow needs permission to push to `homebrew-tools`.

1. GitHub → **Settings → Developer settings → Personal access tokens**
2. Create a **fine-grained** token:
   - Resource owner: `nasraldin`
   - Repository access: only `homebrew-tools`
   - Permissions: **Contents: Read and write**
3. In **docker-lab** → Settings → Secrets and variables → Actions  
   Add secret: **`HOMEBREW_TAP_TOKEN`** = that token

### Verify tap works (after first formula has a real sha256)

```bash
brew tap nasraldin/tools
brew install ducker-lab
ducker version
ducker install
```

Until the first tagged release replaces `REPLACE_WITH_TARBALL_SHA256`, use the [install script](https://github.com/nasraldin/docker-lab#install) instead of `brew install`.

---

## Ongoing publish (automated)

When you cut a release in **docker-lab**:

```bash
# 1. Bump version in config.env
# 2. Tag + GitHub Release
git tag -a v1.0.0 -m "v1.0.0"
git push origin v1.0.0
gh release create v1.0.0 --generate-notes
```

Then the Homebrew job:

1. Downloads `https://github.com/nasraldin/docker-lab/archive/refs/tags/v1.0.0.tar.gz`
2. Computes `sha256`
3. Commits `Formula/ducker-lab.rb` into **`nasraldin/homebrew-tools`** and pushes

Users update with:

```bash
brew update
brew upgrade ducker-lab
```

### Manual publish (if CI secret missing)

```bash
# from docker-lab
./scripts/publish-homebrew.sh v1.0.0
```

Or by hand:

```bash
TAG=v1.0.0
URL="https://github.com/nasraldin/docker-lab/archive/refs/tags/${TAG}.tar.gz"
SHA="$(curl -fsSL "${URL}" | shasum -a 256 | awk '{print $1}')"
# edit ~/homelab/taps/homebrew-tools/Formula/ducker-lab.rb → set url + sha256
# git commit && git push in the tap repo
```

---

## Formula design notes

- Formula name: **`ducker-lab`** (avoids homebrew-core `ducker`)
- Installed CLI: **`ducker`**
- Depends on `lima`, `docker`, `docker-compose`, `docker-buildx`, `yq`, `jq`
- Apple Silicon only (`depends_on arch: :arm64`)
- After `brew install ducker-lab`, users still run **`ducker install`** to create the Lima VM

---

## Troubleshooting

| Symptom | Fix |
| --- | --- |
| `brew info ducker` shows a TUI / ducker.soane.io | That’s **homebrew-core** — unrelated. Use `brew info ducker-lab` |
| `Error: Formula unavailable` | `brew tap nasraldin/tools` then `brew update` |
| CI “Homebrew” fails: permission denied | Missing/expired `HOMEBREW_TAP_TOKEN` |
| `sha256 mismatch` | Tag moved/recreated — never retag; cut a new version |
| Old formula after release | `brew update && brew upgrade ducker-lab` |
| Local tap folder moved but GitHub unchanged | Push from `~/homelab/taps/homebrew-tools` — disk moves are not git |
