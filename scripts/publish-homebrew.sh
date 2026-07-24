#!/usr/bin/env bash
# Publish / update Formula/ducker-lab.rb in nasraldin/homebrew-tools for a given tag.
#
# Usage:
#   ./scripts/publish-homebrew.sh v1.0.0
#   TAP_REPO=nasraldin/homebrew-tools ./scripts/publish-homebrew.sh v1.0.0
#
# Env:
#   TAP_REPO   default: nasraldin/homebrew-tools
#   GH_TOKEN   optional; used by gh when set (CI uses HOMEBREW_TAP_TOKEN)
# shellcheck shell=bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TAG="${1:-}"
TAP_REPO="${TAP_REPO:-nasraldin/homebrew-tools}"
FORMULA_NAME="ducker-lab"

[[ -n "${TAG}" ]] || {
  echo "Usage: $0 <tag>   e.g. $0 v1.0.0" >&2
  exit 1
}
[[ "${TAG}" == v* ]] || {
  echo "ERROR: tag must start with v (got '${TAG}')" >&2
  exit 1
}

VERSION="${TAG#v}"
TARBALL_URL="https://github.com/nasraldin/docker-lab/archive/refs/tags/${TAG}.tar.gz"

command -v gh > /dev/null 2>&1 || {
  echo "ERROR: gh CLI required" >&2
  exit 1
}
command -v shasum > /dev/null 2>&1 || command -v sha256sum > /dev/null 2>&1 || {
  echo "ERROR: shasum or sha256sum required" >&2
  exit 1
}

echo "==> Fetching ${TARBALL_URL}"
TMP="$(mktemp)"
curl -fsSL "${TARBALL_URL}" -o "${TMP}"

if command -v shasum > /dev/null 2>&1; then
  SHA="$(shasum -a 256 "${TMP}" | awk '{print $1}')"
else
  SHA="$(sha256sum "${TMP}" | awk '{print $1}')"
fi
rm -f "${TMP}"
echo "==> sha256 ${SHA}"

WORKDIR="$(mktemp -d)"
cleanup() { rm -rf "${WORKDIR}"; }
trap cleanup EXIT

echo "==> Cloning ${TAP_REPO}"
gh repo clone "${TAP_REPO}" "${WORKDIR}/tap" -- --depth 1
mkdir -p "${WORKDIR}/tap/Formula"

# Render formula from template in this repo
TEMPLATE="${ROOT}/Formula/${FORMULA_NAME}.rb"
[[ -f "${TEMPLATE}" ]] || {
  echo "ERROR: missing ${TEMPLATE}" >&2
  exit 1
}

# Replace url + sha256 lines (keep rest of formula)
awk -v url="${TARBALL_URL}" -v sha="${SHA}" '
  /^  url "/ { print "  url \"" url "\""; next }
  /^  sha256 "/ { print "  sha256 \"" sha "\""; next }
  { print }
' "${TEMPLATE}" > "${WORKDIR}/tap/Formula/${FORMULA_NAME}.rb"

# Remove legacy formula name if present (homebrew-core owns plain "ducker")
rm -f "${WORKDIR}/tap/Formula/ducker.rb"

# Ensure README exists
if [[ ! -f "${WORKDIR}/tap/README.md" ]]; then
  cat > "${WORKDIR}/tap/README.md" << 'EOF'
# nasraldin/homebrew-tools

Homebrew tap for Nasr Aldin tools.

```bash
brew tap nasraldin/tools
brew install ducker-lab
```

Note: formula is `ducker-lab` because homebrew-core already has an unrelated `ducker`.
The CLI binary is still `ducker`.
EOF
fi

cd "${WORKDIR}/tap"
git config user.name "github-actions[bot]"
git config user.email "41898282+github-actions[bot]@users.noreply.github.com"

# Authenticate HTTPS push to the tap (gh clone works; bare git push needs a token URL).
if [[ -n "${GH_TOKEN:-}" ]]; then
  git remote set-url origin "https://x-access-token:${GH_TOKEN}@github.com/${TAP_REPO}.git"
fi

git add Formula/"${FORMULA_NAME}.rb" README.md
git add -u Formula/ducker.rb 2> /dev/null || true
if git diff --cached --quiet; then
  echo "==> No changes (formula already up to date for ${TAG})"
  exit 0
fi

git commit -m "ducker-lab ${VERSION}"
git push origin HEAD
echo "==> Published ${FORMULA_NAME} ${VERSION} → ${TAP_REPO}"
echo "==> Users: brew update && brew upgrade ducker-lab"
