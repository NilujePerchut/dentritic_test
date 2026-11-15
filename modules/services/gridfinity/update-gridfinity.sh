#!/usr/bin/env bash
# update-gridfinity pin
# Usage: ./update-gridfinity.sh — bumps the pinned image version + digest in default.nix
# Differences vs solidcraft's script: upstream publishes NO zip release, so the
# pin is the OCI manifest digest on GHCR, and image tags are NOT release tags
# (latest / X.Y move with patches; X.Y.Z is the fixed one). Hence: anonymous
# token, tag list, pick the highest X.Y.Z, resolve its amd64 digest.
set -euo pipefail
cd "$(dirname "$0")"

repo="andymai/gridfinity-layout-tool"
token=$(curl -fsSL "https://ghcr.io/token?scope=repository:${repo}:pull" | jq -r .token)
auth=(-H "Authorization: Bearer $token")

latest=$(
  curl -fsSL "${auth[@]}" "https://ghcr.io/v2/${repo}/tags/list" \
    | jq -r '.tags[]' \
    | grep -E '^[0-9]+\.[0-9]+\.[0-9]+$' \
    | sort -V | tail -1
)
echo "Latest fixed image tag: $latest"

digest=$(
  curl -fsSL "${auth[@]}" \
    -H "Accept: application/vnd.oci.image.index.v1+json, application/vnd.docker.distribution.manifest.list.v2+json, application/vnd.docker.distribution.manifest.v2+json" \
    "https://ghcr.io/v2/${repo}/manifests/$latest" \
    | jq -r 'if .manifests then
        (.manifests[] | select(.platform.architecture=="amd64") | .digest)
      else
        .config.digest
      end'
)
echo "amd64 manifest digest: $digest"

sed -i "s/version = \".*\"/version = \"$latest\"/" default.nix
sed -i "s/imageDigest = \"sha256:.*\"/imageDigest = \"$digest\"/" default.nix
echo "Pinned $latest ($digest). Rebuild with: sudo nixos-rebuild switch --flake .#osdeplacard"
