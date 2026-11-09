{
  moduleWithSystem,
  ...
}:

{
  flake.nixosModules.solidcraft = moduleWithSystem
    (
      { pkgs }:
      {
        config,
        lib,
        ...
      }:
      let
        cfg = config.services.solidcraftWeb;

        # Fetch the prebuilt static web bundle and unpack it into the store.
        # `pkgs` comes from moduleWithSystem, never from the module header.
        solidcraftWebRoot = pkgs.stdenv.mkDerivation {
          pname = "solidcraft-web";
          version = cfg.version;
          src = pkgs.fetchurl {
            url = "https://github.com/tangency-labs/solidcraft/releases/download/v${cfg.version}/solidcraft-web-${cfg.version}.zip";
            # SHA256 of the release zip (v0.30.1, from the release assets).
            # Update together with `version` (see scripts/update-solidcraft.sh).
            sha256 = "acaa73a5638206cf123c56b4c0a5113c83a8bf0149dee6a66b929b00fe444403";
          };
          nativeBuildInputs = [ pkgs.unzip ];
          installPhase = ''
            runHook preInstall
            mkdir -p $out
            unzip -q $src -d $out
            # Flatten: if the zip has a single top-level directory, hoist it.
            if [ ! -f $out/index.html ] && [ -f $out/*/index.html ]; then
              top=$(shopt -s nullglob; set -- $out/*/; echo "''${1%/}")
              mv "$top"/* "$top"/.* $out/ 2>/dev/null || true
              rmdir "$top"
            fi
            runHook postInstall
          '';
        };

        # Minimal, deterministic mimetypes: wasm is the one that matters
        # (browsers refuse to stream-compile .wasm served as octet-stream).
        mimeTypes = pkgs.writeText "solidcraft-mime.types" ''
          text/html                    html htm
          text/css                     css
          text/javascript              js mjs
          application/wasm             wasm
          application/json             json
          application/octet-stream     bin wasm.data
          image/png                    png
          image/jpeg                   jpg jpeg
          image/svg+xml                 svg
          image/x-icon                 ico
          font/woff                    woff
          font/woff2                   woff2
          text/plain                   txt md
        '';
      in
      {
        options.services.solidcraftWeb = {
          enable = lib.mkEnableOption "SolidCraft web (static CAD app served by a dedicated darkhttpd service)";

          version = lib.mkOption {
            type = lib.types.str;
            default = "0.30.1"; # solidcraft pin
            description = "SolidCraft release version to serve (must exist as a GitHub release).";
          };

          port = lib.mkOption {
            type = lib.types.port;
            default = 8095;
            description = "TCP port darkhttpd listens on.";
          };

          listenAddress = lib.mkOption {
            type = lib.types.str;
            default = "0.0.0.0";
            description = "Address darkhttpd binds (LAN-wide by default, like immich).";
          };

          openFirewall = lib.mkOption {
            type = lib.types.bool;
            default = false;
            description = "Open the firewall port (off: firewall is disabled on osdetv).";
          };
          installUpdateTools = lib.mkOption {
            type = lib.types.bool;
            default = true;
            description = ''
              Install jq and curl in environment.systemPackages. Not needed by
              the service itself (darkhttpd has no dependency), but by
              scripts/update-solidcraft.sh when it runs on this host from the
              repo checkout.
            '';
          };
        };

        config = lib.mkIf cfg.enable {
          # Tools for the version-pin update script, when run on this host.
          environment.systemPackages = lib.optionals cfg.installUpdateTools [
            pkgs.jq
            pkgs.curl
          ];
          # Dedicated, sandboxed static server: dynamic user, no write
          # access anywhere, no state. Nothing to alert on beyond the unit
          # itself (covered by systemd OnFailure hooks if added later).
          systemd.services.solidcraft-web = {
            description = "SolidCraft web (static WASM CAD app)";
            after = [ "network.target" ];
            wantedBy = [ "multi-user.target" ];

            serviceConfig = {
              ExecStart = lib.concatStringsSep " " [
                "${lib.getExe' pkgs.darkhttpd "darkhttpd"}"
                solidcraftWebRoot
                "--port"
                (toString cfg.port)
                "--addr"
                cfg.listenAddress
                "--mimetypes"
                mimeTypes
                "--no-listing"
              ];
              DynamicUser = true;
              User = "solidcraft";
              Group = "solidcraft";
              # Store path is read-only anyway; hardening is cheap here.
              ReadOnlyPaths = [ solidcraftWebRoot ];
              NoNewPrivileges = true;
              PrivateTmp = true;
              ProtectSystem = "strict";
              ProtectHome = true;
              RestrictAddressFamilies = [
                "AF_INET"
                "AF_INET6"
              ];
              Restart = "on-failure";
            };
          };
        };
      }
    );
}
