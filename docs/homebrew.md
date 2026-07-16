# Homebrew

The CLI is named `ducker`. On Homebrew the formula is **`ducker-lab`**, because core already has an unrelated formula called [`ducker`](https://formulae.brew.sh/formula/ducker) (a Docker TUI).

```bash
brew tap nasraldin/tools
brew install ducker-lab
ducker version
```

The tap repo is [`nasraldin/homebrew-tools`](https://github.com/nasraldin/homebrew-tools)  
(`brew tap user/name` maps to `user/homebrew-name`).

---

## Status

| Piece | Status |
| --- | --- |
| Formula in docker-lab | `Formula/ducker-lab.rb` |
| Tap repo | [`nasraldin/homebrew-tools`](https://github.com/nasraldin/homebrew-tools) |
| Local clone (handy) | `~/homelab/taps/homebrew-tools` |
| Auto-update on GitHub Release | workflow (needs `HOMEBREW_TAP_TOKEN`) |
| Official Homebrew core | not used — custom tap only |

Until the first tagged release fills in a real `sha256`, prefer the [install script](https://github.com/nasraldin/docker-lab#install) over `brew install`.

---

## Local clone of the tap

Keep the tap next to docker-lab:

```bash
mkdir -p ~/homelab/taps
cd ~/homelab/taps
git clone https://github.com/nasraldin/homebrew-tools.git
```

```text
~/homelab/
  docker-lab/
  taps/
    homebrew-tools/
```

Copy the formula in when you’re editing by hand:

```bash
cp ~/homelab/docker-lab/Formula/ducker-lab.rb \
   ~/homelab/taps/homebrew-tools/Formula/ducker-lab.rb
rm -f ~/homelab/taps/homebrew-tools/Formula/ducker.rb   # old name — drop it

cd ~/homelab/taps/homebrew-tools
git add Formula/ducker-lab.rb
git add -u Formula/ducker.rb
git commit -m "ducker-lab: sync formula from docker-lab"
git push origin main
```

Moving folders on disk does **not** update GitHub. Commit and push in `homebrew-tools`, or let the release workflow do it.

---

## CI secret (for auto-publish)

The docker-lab release workflow needs permission to push to `homebrew-tools`.

1. GitHub → **Settings → Developer settings → Personal access tokens**
2. Create a **fine-grained** token:
   - Resource owner: `nasraldin`
   - Repo access: only `homebrew-tools`
   - Permissions: **Contents: Read and write**
3. In **docker-lab** → Settings → Secrets and variables → Actions  
   Add secret: **`HOMEBREW_TAP_TOKEN`** = that token

### Check it works (after the formula has a real sha256)

```bash
brew tap nasraldin/tools
brew install ducker-lab
ducker version
ducker install
```

---

## Publishing on release

Cut a release in **docker-lab**:

```bash
# 1. Bump version in config.env
# 2. Tag + GitHub Release
git tag -a v1.0.0 -m "v1.0.0"
git push origin v1.0.0
gh release create v1.0.0 --generate-notes
```

The Homebrew job then:

1. Downloads `https://github.com/nasraldin/docker-lab/archive/refs/tags/v1.0.0.tar.gz`
2. Computes `sha256`
3. Commits `Formula/ducker-lab.rb` into **`nasraldin/homebrew-tools`** and pushes

Users update with:

```bash
brew update
brew upgrade ducker-lab
```

### Manual publish (no CI secret)

```bash
# from docker-lab
./scripts/publish-homebrew.sh v1.0.0
```

Or by hand:

```bash
TAG=v1.0.0
URL="https://github.com/nasraldin/docker-lab/archive/refs/tags/${TAG}.tar.gz"
SHA="$(curl -fsSL "${URL}" | shasum -a 256 | awk '{print $1}')"
# edit the tap formula → set url + sha256
# git commit && git push in homebrew-tools
```

---

## Formula notes

- Formula name: **`ducker-lab`**
- Installed CLI: **`ducker`**
- Depends on `lima`, `docker`, `docker-compose`, `docker-buildx`, `yq`, `jq`
- Apple Silicon only (`depends_on arch: :arm64`)
- After `brew install`, still run **`ducker install`** to create the Lima VM

---

## Troubleshooting

| Symptom | Fix |
| --- | --- |
| `brew info ducker` shows a TUI / ducker.soane.io | That’s **homebrew-core** — unrelated. Use `brew info ducker-lab` |
| `Error: Formula unavailable` | `brew tap nasraldin/tools` then `brew update` |
| CI “Homebrew” fails: permission denied | Missing or expired `HOMEBREW_TAP_TOKEN` |
| `sha256 mismatch` | Tag was moved — don’t retag; cut a new version |
| Old formula after release | `brew update && brew upgrade ducker-lab` |
| Local tap folder moved but GitHub unchanged | Push from `~/homelab/taps/homebrew-tools` |
