# Homebrew formula for the nasraldin/tools tap (repo: nasraldin/homebrew-tools).
#
# Formula name is ducker-lab (not "ducker") because homebrew-core already has
# https://formulae.brew.sh/formula/ducker — a different Docker TUI project.
# The installed CLI binary is still named `ducker`.
#
# This file is the source of truth. On GitHub Release, CI runs
# scripts/publish-homebrew.sh to push an updated copy into the tap with the
# correct url + sha256. See docs/homebrew.md for setup.
#
# Users:
#   brew tap nasraldin/tools
#   brew install ducker-lab
#
class DuckerLab < Formula
  desc "Native Linux Docker on Apple Silicon (Lima vz + rootless Engine)"
  homepage "https://github.com/nasraldin/docker-lab"
  url "https://github.com/nasraldin/docker-lab/archive/refs/tags/v1.0.1.tar.gz"
  sha256 "44119eb58a85597af910fb907a52b69877829e34195463ca541271b42a72cfb2"
  license "MIT"

  depends_on arch: :arm64
  depends_on "docker"
  depends_on "docker-buildx"
  depends_on "docker-compose"
  depends_on "docker-credential-helper"
  depends_on "jq"
  depends_on "lima"
  depends_on :macos
  depends_on "yq"

  def install
    prefix.install Dir["*"]
    bin.install_symlink prefix/"ducker"
  end

  def caveats
    <<~EOS
      The CLI is `ducker` (formula name is ducker-lab to avoid homebrew-core's unrelated `ducker`).

      After install, create the lab VM and Docker stack:

        ducker install
        ducker verify

      Docs: https://nasraldin.github.io/docker-lab/
    EOS
  end

  test do
    assert_match "Docker Lab", shell_output("#{bin}/ducker version")
  end
end
