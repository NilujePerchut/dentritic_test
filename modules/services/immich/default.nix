{
  self,
  moduleWithSystem,
  ...
}: {
  flake.nixosModules.immich =
    moduleWithSystem
    ({pkgs, ...}: {config, lib, ...}: let
      cfg = config.services.immichNas;
    in {
      options.services.immichNas = {
        # ── Options: thin facade over the upstream services.immich module ──
        # Note: the option namespace cannot be `services.immich` — it is
        # already declared by the official NixOS module (same reason the
        # Samba facade uses `services.smb` over upstream `services.samba`).

        enable = lib.mkEnableOption "Immich (self-hosted photo & video backup from mobiles, native NixOS services)";

        dataDir = lib.mkOption {
          type = lib.types.str;
          default = "/mnt/mergerfs/immich";
          description = "Library location: photos and videos live on the MergerFS pool (protected by SnapRAID parity)";
        };

        port = lib.mkOption {
          type = lib.types.port;
          default = 2283;
          description = "Immich server port";
        };

        user = lib.mkOption {
          type = lib.types.str;
          default = "immich";
          description = "User the service runs as — must be the pool owner when dataDir is on mergerfs";
        };

        group = lib.mkOption {
          type = lib.types.str;
          default = "immich";
          description = "Group the service runs as";
        };

        machineLearning = lib.mkEnableOption "semantic search and face detection (+1-2 GiB RAM, runs on CPU)";

        domain = lib.mkOption {
          type = lib.types.nullOr lib.types.str;
          default = null;
          example = "photos.example.com";
          description = "Public domain: enables nginx + TLS. Leave null for LAN-only http access";
        };

        settings = lib.mkOption {
          type = lib.types.attrsOf lib.types.anything;
          default = {};
          description = "Pass-through to services.immich.settings — see https://immich.app/docs/install/config-file/";
        };
      };

      config = lib.mkIf cfg.enable {
        # ── Facade to the upstream module ──────────────────────────
        # Postgres and Redis are provisioned and wired automatically
        # by services.immich. Database backups are NOT handled here:
        # they belong to the stateBackup module (system-wide concern).
        services.immich = {
          enable = true;
          port = cfg.port;
          host = "0.0.0.0";
          mediaLocation = cfg.dataDir;
          machine-learning.enable = cfg.machineLearning;
          inherit (cfg) user group;
          settings = {} // cfg.settings;
        };

        # ── Library on the pool: directory must belong to the service user,
        # which must be the pool owner (see mergerfs uid/gid in the nas module).
        systemd.tmpfiles.rules = [
          "d ${cfg.dataDir} 0755 ${cfg.user} ${cfg.group} -"
        ];

        # ── LAN exposure (no firewall on our hosts, kept for reuse) ──
        networking.firewall.allowedTCPPorts =
          lib.optional (cfg.domain == null) cfg.port;

        # ── Optional public vhost (nginx + ACME TLS) ───────────────
        services.nginx = lib.mkIf (cfg.domain != null) {
          enable = true;
          virtualHosts.${cfg.domain} = {
            enableACME = true;
            forceSSL = true;
            locations."/".proxyPass = "http://localhost:${toString cfg.port}";
          };
        };
        security.acme = lib.mkIf (cfg.domain != null) {
          acceptTerms = true;
          defaults.email = "you@example.com"; # adjust per host or per domain
        };
      };
    });
}
