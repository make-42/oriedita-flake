#!/usr/bin/env bash
# Bumps version.json to the latest upstream release and recomputes both hashes.
# Set FORCE=1 to recompute even if the version is unchanged.
set -euo pipefail
cd "$(dirname "$0")/.."

fake="sha256-AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA="

auth=()
[ -n "${GITHUB_TOKEN:-}" ] && auth=(-H "Authorization: Bearer $GITHUB_TOKEN")

current=$(jq -r .version version.json)
tag=$(curl -fsSL ${auth[@]+"${auth[@]}"} \
  https://api.github.com/repos/oriedita/oriedita/releases/latest | jq -r .tag_name)
latest=${tag#v}

if [ "$latest" = "$current" ] && [ "${FORCE:-0}" != 1 ]; then
  echo "Already up to date ($current)"
  exit 0
fi
echo "Updating $current -> $latest"

write() {
  jq -n --arg v "$1" --arg s "$2" --arg m "$3" \
    '{version: $v, srcHash: $s, mvnHash: $m}' > version.json
}

# 1. Source hash
src=$(nix flake prefetch "github:oriedita/oriedita/$tag" --json | jq -r .hash)

# 2. Maven deps hash: build with a fake hash and read the real one from the error
write "$latest" "$src" "$fake"
out=$(nix build .#oriedita --no-link 2>&1 || true)
mvn=$(grep -oP 'got:\s+\Ksha256-\S+' <<<"$out" | head -n1 || true)
if [ -z "$mvn" ]; then
  echo "Could not determine mvnHash. Build output:" >&2
  echo "$out" >&2
  git checkout version.json
  exit 1
fi
write "$latest" "$src" "$mvn"

# 3. Verify the final build
nix build .#oriedita --no-link -L
echo "Updated to $latest"
