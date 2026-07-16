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
  url "https://github.com/nasraldin/docker-lab/archive/refs/tags/v1.0.0.tar.gz"
  sha256 "afb8149d0ff6c4aa4cafe591b4f1fc1c02803fede5c285d26479d5c54d1e1c0e"
  license "MIT"

  depends_on "lima"
  depends_on "docker"
  depends_on "docker-compose"
  depends_on "docker-buildx"
  depends_on "yq"
  depends_on "jq"
  depends_on :macos
  depends_on arch: :arm64

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
