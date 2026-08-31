#!/usr/bin/env bash
#
# Bump package.nix to the current stable Grok Bot release.
#
# Reads version, commitSha, and debUrl from:
#   https://api2.cursor.sh/updates/api/download/stable/linux-{x64,arm64}/sand
# Prefetches both .debs, validates Debian metadata, then rewrites package.nix.
#
# Optional: pass a linux-x64 debUrl to pin that build (arm64 URL is derived).
#   ./update.sh https://downloads.cursor.com/grokbot/stable/<sha>/linux/x64/grok-bot_<ver>_amd64.deb

set -euo pipefail

cd "$(dirname "$(readlink -f "$0")")"

if [[ "${GROK_BOT_UPDATE_ENV:-}" != 1 ]]; then
  exec nix shell --inputs-from . \
    nixpkgs#bash \
    nixpkgs#curl \
    nixpkgs#jq \
    nixpkgs#coreutils \
    nixpkgs#gnused \
    nixpkgs#nix \
    nixpkgs#dpkg \
    --command env GROK_BOT_UPDATE_ENV=1 bash ./update.sh "$@"
fi

FEED="https://api2.cursor.sh/updates/api/download/stable"

parse_deb_url() {
  local url="$1"
  commitSha="$(sed -En 's|^https://downloads\.cursor\.com/grokbot/stable/([0-9a-f]{40})/.*$|\1|p' <<<"$url")"
  version="$(sed -En 's|.*/grok-bot_([^/_]+)_amd64\.deb$|\1|p' <<<"$url")"
  if [[ ! "$commitSha" =~ ^[0-9a-f]{40}$ ]] || [[ -z "$version" ]]; then
    echo "error: could not parse commitSha/version from: $url" >&2
    exit 1
  fi
}

case $# in
  0)
    x64_json="$(curl --retry 3 --retry-all-errors -fsSL "$FEED/linux-x64/sand")"
    arm_json="$(curl --retry 3 --retry-all-errors -fsSL "$FEED/linux-arm64/sand")"
    version="$(jq -er '.version' <<<"$x64_json")"
    commitSha="$(jq -er '.commitSha' <<<"$x64_json")"
    arm_version="$(jq -er '.version' <<<"$arm_json")"
    arm_commit="$(jq -er '.commitSha' <<<"$arm_json")"
    x64_url="$(jq -er '.debUrl' <<<"$x64_json")"
    arm_url="$(jq -er '.debUrl' <<<"$arm_json")"
    if [ "$version" != "$arm_version" ] || [ "$commitSha" != "$arm_commit" ]; then
      echo "error: x64 ($version $commitSha) and arm64 ($arm_version $arm_commit) feeds disagree" >&2
      exit 1
    fi
    ;;
  1)
    x64_url="$1"
    parse_deb_url "$x64_url"
    arm_url="https://downloads.cursor.com/grokbot/stable/${commitSha}/linux/arm64/grok-bot_${version}_arm64.deb"
    ;;
  *)
    echo "usage: $0 [linux-x64 grok-bot_VERSION_amd64.deb URL]" >&2
    exit 2
    ;;
esac

if [[ ! "$version" =~ ^[0-9][0-9A-Za-z._+~-]*$ ]]; then
  echo "error: invalid release version: $version" >&2
  exit 1
fi

read_attr() {
  sed -n "s/^  $1 = \"\\(.*\\)\";$/\\1/p" package.nix | head -n1
}

# Only the `hashes = { ... };` attrset — archTag/debArch use the same keys.
read_hash() {
  sed -n "/^  hashes = {/,/^  };/ s/^    $1 = \"\\(.*\\)\";$/\\1/p" package.nix
}

current_version="$(read_attr version)"
current_commit="$(read_attr commitSha)"
current_hash_x64="$(read_hash x86_64-linux)"
current_hash_arm="$(read_hash aarch64-linux)"

if [ -z "$current_version" ] || [ -z "$current_commit" ] \
  || [ -z "$current_hash_x64" ] || [ -z "$current_hash_arm" ]; then
  echo "error: could not read current release metadata from package.nix" >&2
  exit 1
fi

prefetch_and_check() {
  local url="$1" expect_arch="$2"
  echo "prefetching $url" >&2
  local prefetch path pkg ver arch hash
  prefetch="$(nix store prefetch-file --json --hash-type sha256 "$url")"
  hash="$(jq -er '.hash' <<<"$prefetch")"
  path="$(jq -er '.storePath' <<<"$prefetch")"
  pkg="$(dpkg-deb -f "$path" Package)"
  ver="$(dpkg-deb -f "$path" Version)"
  arch="$(dpkg-deb -f "$path" Architecture)"
  case "$pkg" in
    sand | grok-bot) ;;
    *)
      echo "error: expected package sand/grok-bot, got '$pkg'" >&2
      exit 1
      ;;
  esac
  if [ "$ver" != "$version" ]; then
    echo "error: feed version '$version' does not match .deb version '$ver'" >&2
    exit 1
  fi
  if [ "$arch" != "$expect_arch" ]; then
    echo "error: expected $expect_arch .deb, got '$arch'" >&2
    exit 1
  fi
  printf '%s\n' "$hash"
}

hash_x64="$(prefetch_and_check "$x64_url" amd64)"
hash_arm="$(prefetch_and_check "$arm_url" arm64)"

if [ "$version" = "$current_version" ] \
  && [ "$commitSha" = "$current_commit" ] \
  && [ "$hash_x64" = "$current_hash_x64" ] \
  && [ "$hash_arm" = "$current_hash_arm" ]; then
  echo "already at $version ($commitSha)"
  exit 0
fi

echo "$current_version ($current_commit) -> $version ($commitSha)" >&2

sed -i \
  -e "s|^  version = \".*\";$|  version = \"${version}\";|" \
  -e "s|^  commitSha = \".*\";$|  commitSha = \"${commitSha}\";|" \
  -e "/^  hashes = {/,/^  };/ s|^    x86_64-linux = \".*\";$|    x86_64-linux = \"${hash_x64}\";|" \
  -e "/^  hashes = {/,/^  };/ s|^    aarch64-linux = \".*\";$|    aarch64-linux = \"${hash_arm}\";|" \
  package.nix

if [ "$(read_attr version)" != "$version" ] \
  || [ "$(read_attr commitSha)" != "$commitSha" ] \
  || [ "$(read_hash x86_64-linux)" != "$hash_x64" ] \
  || [ "$(read_hash aarch64-linux)" != "$hash_arm" ]; then
  echo "error: failed to write all release metadata to package.nix" >&2
  exit 1
fi

echo "package.nix updated to $version"
