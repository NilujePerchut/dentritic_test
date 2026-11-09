#!/usr/bin/env bash
# Update the SolidCraft web version pin in the NixOS module.
#
# Pins the latest STABLE release (GitHub /releases/latest never returns
# prereleases) by rewriting the two lines marked "# solidcraft pin" plus the
# fetchurl sha256 in the default.nix sitting next to this script.
#
# Co-located with the module: everything for the service (module + updater)
# lives in modules/services/solidcraft/. Works from any directory; jq and
# curl are provided on the host by the module option installUpdateTools.
#
# Usage:
#   bash modules/services/solidcraft/update-solidcraft.sh
#
# After running: review the diff, commit, push, then:
#   sudo nixos-rebuild switch --flake .#osdeplacard

set -euo pipefail

REPO="tangency-labs/solidcraft"
MODULE="$(cd "$(dirname "$(readlink -f "$0")")" && pwd)/default.nix"

[ -f "$MODULE" ] || { echo "ERROR: module not found: $MODULE" >&2; exit 1; }
command -v jq >/dev/null || { echo "ERROR: jq is required" >&2; exit 1; }
command -v curl >/dev/null || { echo "ERROR: curl is required" >&2; exit 1; }

# --- 1. Latest stable release tag (prereleases excluded by the API) ---------
release_json=$(curl -fsSL "https://api.github.com/repos/${REPO}/releases/latest")
tag=$(jq -r '.tag_name' <<<"$release_json")
case "$tag" in
  v[0-9]*) version=${tag#v} ;;
  *) echo "ERROR: unexpected tag from GitHub API: '$tag'" >&2; exit 1 ;;
esac

asset_name="solidcraft-web-${version}.zip"

# --- 2. Zip sha256: release asset digest, fallback to SHA256SUMS.txt --------
sha=$(jq -r --arg n "$asset_name" \
  '.assets[] | select(.name == $n) | .digest // empty' <<<"$release_json" \
  | sed 's/^sha256://')
if [ -z "$sha" ]; then
  sums_url=$(jq -r --arg n "SHA256SUMS.txt" \
    '.assets[] | select(.name == $n) | .browser_download_url' <<<"$release_json")
  if [ -n "$sums_url" ] && [ "$sums_url" != "null" ]; then
    sha=$(curl -fsSL "$sums_url" | awk -v f="$asset_name" '$2 == f {print $1}')
  fi
fi

# Sanity check: must be exactly 64 hex chars.
if ! [[ "$sha" =~ ^[0-9a-f]{64}$ ]]; then
  echo "ERROR: no valid sha256 found for $asset_name (got: '${sha:-<empty>}')" >&2
  echo "       Upstream may have renamed the asset; pin manually." >&2
  exit 1
fi

# --- 3. Guard: refuse to rewrite an unrecognized pin layout -----------------
grep -q '# solidcraft pin' "$MODULE" \
  || { echo "ERROR: '# solidcraft pin' marker not found in $MODULE" >&2; exit 1; }

# --- 4. Rewrite the pin -----------------------------------------------------
sed -i -E \
  "s|default = \"[^\"]*\";(# solidcraft pin)|default = \"${version}\";\1|" "$MODULE"
sed -i -E \
  "s|sha256 = \"[0-9a-f]{64}\";|sha256 = \"${sha}\";|" "$MODULE"

# --- 5. Verify both rewrites landed ----------------------------------------
grep -q "default = \"${version}\"; # solidcraft pin" "$MODULE" \
  || { echo "ERROR: version rewrite failed" >&2; exit 1; }
grep -q "sha256 = \"${sha}\";" "$MODULE" \
  || { echo "ERROR: sha256 rewrite failed" >&2; exit 1; }

echo "solidcraft-web pinned to ${version} (sha256 ${sha:0:12}…)"
echo "Next: git diff ${MODULE} && git commit && nixos-rebuild switch"
