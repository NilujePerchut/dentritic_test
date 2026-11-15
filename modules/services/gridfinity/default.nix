# Gridfinity Layout Tool — self-hosted static web app (gridfinity-layout-tool)
# Pattern: same as solidcraft (flake-parts facade, static binary serving,
# zero server state). Upstream ships only an OCI image whose nginx serves
# static files; we extract the web root from the pinned image at build time
# and serve it with static-web-server (needs custom headers + SPA fallback,
# which darkhttpd cannot do).
{
  config,
  lib,
  ...
}:
let
  # Pinned upstream image. Update with update-gridfinity.sh (see repo,
  # next to this file) — one command, never by hand.
  version = "4.514.0";
  # sha256 digest of the image manifest (architecture-specific; this is amd64).
  imageDigest = "sha256:b067cc3786c85ca8310342fd0f0c3dec423709f7a6d5864078773ee72550e764";
in
{
  perSystem = { ... }: { };
  flake.nixosModules.gridfinity =
    { config, lib, pkgs, ... }:
    let
      cfg = config.services.gridfinity;

      # Extract the web root from the pinned OCI image (the image is
      # nginx + static files; we untar its layers and keep /usr/share/nginx/html).
      # Fixed-output derivation: only FODs get network access in the Nix
      # build sandbox. Integrity is enforced by outputHash.
      webRoot = pkgs.stdenv.mkDerivation {
        name = "gridfinity-web-${version}";
        nativeBuildInputs = with pkgs; [
          skopeo
          jq
          gnutar
        ];
        outputHashAlgo = "sha256";
        outputHashMode = "recursive";
        outputHash = "sha256-E95juf1EFzXmS1wH+QIJ4YHdOeaPwZM13tCRwCOIvpA=";
        buildCommand = ''

          set -euo pipefail
          # skopeo in the Nix sandbox has no containers trust policy (HOME is
          # /homeless-shelter): provide a permissive one. Integrity does NOT
          # come from here — it comes from the pinned digest above.
          export HOME=$PWD
          mkdir -p $HOME/.config/containers
          printf '%s\n' '{"default":[{"type":"insecureAcceptAnything"}]}' \
            > $HOME/.config/containers/policy.json
          mkdir -p $out img
          # Copy the image into a local OCI layout (no daemon, pure fetch).
          skopeo copy \
            docker://ghcr.io/andymai/gridfinity-layout-tool@${imageDigest} \
            oci:$PWD/img
          manifest=$(jq -r '.manifests[0].digest | split(":")[1]' img/index.json)
          # Untar every layer in order into a scratch root.
          mkdir scratch
          for h in $(jq -r '.layers[].digest | split(":")[1]' img/blobs/sha256/$manifest); do
            tar -xf img/blobs/sha256/$h -C scratch
          done
          # The nginx document root inside the image.
          cp -r scratch/usr/share/nginx/html/. $out/
          # Sanity: the app shell must be there, or fail the build loudly.
          test -f $out/index.html || exit 1
          test -f $out/version.json || exit 1
        '';
      };

      # static-web-server configuration (TOML). See SWS docs for the exact
      # field names of the pinned nixpkgs version — verify before first build
      # (convention: never trust option names from memory).
      swsConfig = pkgs.writeText "gridfinity-sws.toml"
        ''
          [general]
          port = ${toString cfg.port}
          root = "${webRoot}"
          # SPA-style fallback: in-app routes resolve to the app shell.
          page-fallback = "index.html"

          [advanced]
          # No directory listing (same hardening as solidcraft darkhttpd --no-listing).
          directory-listing = false

          # Custom headers required by the app (see upstream docker/nginx.conf
          # and docs/self-hosting.md). COOP/COEP enable crossOriginIsolated
          # for the geometry kernels.
          [[advanced.headers]]
          source = "**/*"
          [advanced.headers.headers]
          "Cross-Origin-Opener-Policy" = "same-origin"
          "Cross-Origin-Embedder-Policy" = "require-corp"
          "Referrer-Policy" = "no-referrer"
          "X-Content-Type-Options" = "nosniff"
        '';

      swsPackage = pkgs.static-web-server;
    in
    {
      options.services.gridfinity = {
        enable = lib.mkEnableOption "gridfinity-layout-tool web app";
        port = lib.mkOption {
          type = lib.types.port;
          default = 8096;
          description = "LAN port to serve the app on.";
        };
      };

      config = lib.mkIf cfg.enable {
        systemd.services.gridfinity-web = {
          description = "gridfinity-layout-tool static web app";
          after = [ "network.target" ];
          wantedBy = [ "multi-user.target" ];
          serviceConfig = {
            ExecStart = "${swsPackage}/bin/static-web-server --config-file ${swsConfig}";
            DynamicUser = true;
            # Read-only serving: the app stores everything in the browser.
            ProtectSystem = "strict";
            StateDirectory = ""; # no state — deliberate (invariant #4 n/a)
          };
        };
      };
    };
}
