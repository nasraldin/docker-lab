#!/usr/bin/env bash
# Exercise upgrade preview with isolated host tools and a simulated Lima guest.
set -euo pipefail

repo="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
fixture="$(mktemp -d)"
trap 'rm -rf -- "${fixture}"' EXIT
mkdir -p "${fixture}/bin" "${fixture}/config" "${fixture}/apps/ui/dockhand"
printf "{}\n" >"${fixture}/config/daemon.json"
printf 'brew "lima"\nbrew "docker"\nbrew "jq"\n' >"${fixture}/Brewfile"
cp "${repo}/apps/ui/dockhand/compose.yaml" "${fixture}/apps/ui/dockhand/compose.yaml"
# A preview must not execute or print UI environment contents.
printf 'printf "unexpected env execution" >"%s/env-executed"\n' "${fixture}" >"${fixture}/apps/ui/dockhand/.env"

cat >"${fixture}/bin/fixture-tool" <<'STUB'
#!/usr/bin/env bash
set -euo pipefail

case "$(basename "$0") $*" in
  'uname -s') printf 'Darwin\n' ;;
  'uname -m') printf 'arm64\n' ;;
  'brew list --formula --versions') printf 'docker 29.0\nlima 2.0\n' ;;
  'brew outdated --formula --verbose') printf 'docker (29.0) < 29.1\nother (1.0) < 2.0\n' ;;
  'limactl list -q') printf 'docker\n' ;;
  "limactl list -f {{.Name}} {{.Status}}") printf 'docker %s\n' "${VM_STATUS}" ;;
  'limactl shell docker -- env LC_ALL=C apt-cache -o Dir::Cache::pkgcache= -o Dir::Cache::srcpkgcache= policy '*)
    printf 'docker-ce:\n  Installed: 29.0\n  Candidate: 29.1\n     29.1 500\n        500 https://download.docker.com/linux/debian trixie/stable arm64 Packages\n'
    ;;
  'limactl shell docker -- bash -c '*) printf "changed\n" ;;
  "docker --host "*' container ls --all --format {{.Names}}') printf 'ui-dockhand\n' ;;
  "docker --host "*' container inspect --format {{.Image}} ui-dockhand') printf 'sha256:local\n' ;;
  'docker manifest inspect --verbose -- fnsys/dockhand:latest')
    printf '[{"Descriptor":{"platform":{"os":"linux","architecture":"amd64"}},"OCIManifest":{"config":{"digest":"sha256:local"}}},{"Descriptor":{"platform":{"os":"linux","architecture":"arm64"}},"OCIManifest":{"config":{"digest":"sha256:new"}}}]\n'
    ;;
  *)
    printf '%s %s\n' "$0" "$*" >>"${ROOT_DIR}/unexpected"
    exit 99
    ;;
esac
STUB
chmod +x "${fixture}/bin/fixture-tool"
for name in uname brew limactl docker; do
  ln -s fixture-tool "${fixture}/bin/${name}"
done

# A plan requires jq for container image metadata. On hosts without jq, the
# plan reports the check as unavailable.
if ! command -v jq >/dev/null 2>&1; then
  printf 'SKIP upgrade plan integration test (jq unavailable)\n'
  exit 0
fi

# Shellenv can reorder PATH, so keep Homebrew isolated in the apply path too.
brew() { "${ROOT_DIR}/bin/brew" "$@"; }
export -f brew

run_upgrade() {
  local status="$1"
  shift
  VM_STATUS="${status}" INSTANCE_NAME=docker CLI_PLUGINS_DIR=/test/plugins ROOT_DIR="${fixture}" PATH="${fixture}/bin:${PATH}" \
    bash "${repo}/scripts/upgrade.sh" "$@" 2>&1
}

assert_output() {
  local expected="$1"
  case "${output}" in
    *"${expected}"*) ;;
    *)
      printf 'Expected upgrade preview to contain %s\n%s\n' "${expected}" "${output}" >&2
      exit 1
      ;;
  esac
}

if ! output="$(run_upgrade Running --plan)"; then
  printf 'Upgrade preview for a running instance failed\n%s\n' "${output}" >&2
  exit 1
fi
assert_output 'docker (29.0) < 29.1'
assert_output 'jq is missing'
assert_output 'docker-ce  installed 29.0, cached candidate 29.1'
assert_output 'dockhand'
assert_output 'sha256:local'
assert_output 'sha256:new'
assert_output 'Image update available'
assert_output 'restart rootless Docker'
assert_output 'hello-world'
[[ "${output}" != *'other (1.0)'* ]]

output="$(run_upgrade Stopped --plan)"
assert_output 'Stopped'
assert_output 'Guest package information unavailable'
assert_output 'Local image unavailable'
assert_output 'sha256:new'
assert_output 'ducker verify'

if output="$(run_upgrade Running --unknown)"; then
  printf 'Upgrade unexpectedly accepted an unknown argument\n' >&2
  exit 1
fi
assert_output 'Usage: ducker upgrade'

[[ ! -e "${fixture}/unexpected" ]] || {
  cat "${fixture}/unexpected" >&2
  exit 1
}
[[ ! -e "${fixture}/env-executed" ]]
printf 'Upgrade plan reports changes without running apply operations\n'
