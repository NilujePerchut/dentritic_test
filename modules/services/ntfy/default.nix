{
  self,
  moduleWithSystem,
  ...
}: {
  flake.nixosModules.ntfy =
    moduleWithSystem
    ({pkgs, ...}: {config, lib, ...}: let
      cfg = config.services.ntfy;

      # Sender wrapper: topic as first argument, optional ntfy priority as
      # second, message body on stdin. Reads the access token from the
      # sops-decrypted file at runtime, so token rotation needs no restart.
      ntfySend = pkgs.writeShellScriptBin "ntfy-send" ''
        # Usage: ntfy-send <topic> [priority]   (body on stdin)
        # Optional env: NTFY_TITLE, NTFY_TAG (used for snapraidd placeholders)
        set -eu
        topic="''${1:?topic required}"
        headers=()
        if [ -n "''${NTFY_TITLE:-}" ]; then headers+=(-H "Title: $NTFY_TITLE"); fi
        if [ -n "''${NTFY_TAG:-}" ]; then headers+=(-H "Tag: $NTFY_TAG"); fi
        if [ "''${2:-}" != "" ]; then headers+=(-H "Priority: $2"); fi
        headers+=(-H "Authorization: Bearer $(cat ${cfg.tokenFile})")
        exec ${pkgs.curl}/bin/curl -f --max-time 30 --retry 3 \
          "''${headers[@]}" --data-binary @- \
          "http://127.0.0.1:${toString cfg.port}/$topic"
      '';

      ntfySettings = {
        base-url = "http://${config.networking.hostName}:${toString cfg.port}";
        listen-http = ":${toString cfg.port}";
        cache-file = "${cfg.stateDir}/cache.db";
        auth-file = "${cfg.stateDir}/auth.db";
        attachment-cache-dir = "${cfg.stateDir}/attachments";
        auth-default-access = "deny-all";
      };

    in {
      options.services.ntfy = {
        enable = lib.mkEnableOption "Self-hosted ntfy push notification server";

        port = lib.mkOption {
          type = lib.types.port;
          default = 2586;
          description = "ntfy listen port";
        };

        stateDir = lib.mkOption {
          type = lib.types.str;
          default = "/var/lib/ntfy";
          description = "ntfy state directory (cache + auth db)";
        };

        user = lib.mkOption {
          type = lib.types.str;
          default = "ntfy";
          description = "User running the ntfy service";
        };

        group = lib.mkOption {
          type = lib.types.str;
          default = "ntfy";
          description = "Group running the ntfy service";
        };

        tokenFile = lib.mkOption {
          type = lib.types.str;
          readOnly = true;
          description = "Path of the sops-decrypted access token used by ntfy-send";
        };

        sendScript = lib.mkOption {
          type = lib.types.package;
          readOnly = true;
          description = "ntfy-send wrapper: topic as arg, optional priority, body on stdin";
        };
      };

      config = lib.mkIf cfg.enable {
        # One secret per file, YAML key "token" (sops-nix default key =
        # secret name, hence the explicit override like the samba facade).
        sops.secrets."ntfy-token" = {
          sopsFile = "${self}/secrets/ntfy-token.sops.yaml";
          key = "token";
        };

        services.ntfy = {
          tokenFile = config.sops.secrets."ntfy-token".path;
          sendScript = ntfySend;
        };

        services.ntfy-sh = {
          enable = true;
          inherit (cfg) user group;
          settings = ntfySettings;
        };

        # The upstream module relies on DynamicUser + StateDirectory, which
        # is incompatible with the one-time CLI provisioning of auth.db
        # (invariant #5: a per-boot ephemeral UID cannot own stable state).
        # Run as the static user instead.
        systemd.services.ntfy-sh.serviceConfig = {
          # mkForce: override the upstream DynamicUser=true (equal priority
          # would be a conflict).
          DynamicUser = lib.mkForce false;
          ReadWritePaths = ["${cfg.stateDir}"];
        };

        # The upstream module does not provision the service user:
        # create a dedicated system user for it.
        users.groups.${cfg.group} = {};

        users.users.${cfg.user} = {
          isSystemUser = true;
          group = cfg.group;
          description = "ntfy push notification server";
        };

        environment.systemPackages = [
          pkgs.ntfy-sh # CLI for one-time provisioning and tests
          ntfySend
        ];

        systemd.tmpfiles.rules = [
          "d ${cfg.stateDir} 0700 ${cfg.user} ${cfg.group} -"
        ];

        # If the state dir happens to live inside a mount (other hosts),
        # systemd derives the dependency from the path itself. This is a
        # native systemd directive, hence unitConfig and not a NixOS option.
        systemd.services.ntfy-sh.unitConfig.RequiresMountsFor = ["${cfg.stateDir}"];
      };
    });
}
