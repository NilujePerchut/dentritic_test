{
  self,
  moduleWithSystem,
  ...
}: {
  flake.nixosModules.ntfy =
    moduleWithSystem
    ({pkgs, ...}: {config, lib, ...}: let
      cfg = config.services.ntfy;

      # ─── ntfy-send wrapper ───
      # Usage: ntfy-send <topic> [priority]   (body on stdin)
      # `priority` accepts ntfy priorities (min|low|default|high|urgent)
      # and snapraidd levels (info|warning|error), which are translated.
      # Optional env: NTFY_TITLE, NTFY_TAG (used for snapraidd placeholders).
      # The token is read at runtime from the sops secret, so rotating it
      # does not require restarting anything.
      ntfySend = pkgs.writeShellApplication {
        name = "ntfy-send";
        runtimeInputs = [pkgs.curl];
        text = ''
          set -eu
          topic="''${1:?topic required}"

          # ─── snapraidd levels → ntfy priorities (safety net) ───
          case "''${2:-}" in
            info|INFO)     prio="low" ;;
            warn|warning)  prio="high" ;;
            error|ERROR)   prio="urgent" ;;
            min|low|default|high|urgent) prio="$2" ;;
            "")            prio="" ;;
            *)             prio="default" ;;
          esac

          headers=()
          if [ -n "''${NTFY_TITLE:-}" ]; then headers+=(-H "Title: $NTFY_TITLE"); fi
          if [ -n "''${NTFY_TAG:-}" ]; then headers+=(-H "Tag: $NTFY_TAG"); fi
          if [ -n "$prio" ]; then headers+=(-H "Priority: $prio"); fi

          # Bash-only redirection: the daemon spawns this script with a
          # minimal environment (no PATH), so `cat` is NOT available.
          token="$(</run/secrets/ntfy-token)"
          headers+=(-H "Authorization: Bearer $token")

          exec ${pkgs.curl}/bin/curl -f --max-time 30 --retry 3 \
            "''${headers[@]}" --data-binary @- \
            "http://127.0.0.1:2586/$topic"
        '';
      };

      ntfySettings = {
        base-url = "http://${config.networking.hostName}:${toString cfg.port}";
        listen-http = ":${toString cfg.port}";
        cache-file = "${cfg.stateDir}/cache.db";
        cache-duration = "168h";
        auth-file = "${cfg.stateDir}/auth.db";
        attachment-cache-dir = "${cfg.stateDir}/attachments";
        attachment-expiry-duration = "168h";
        auth-default-access = "deny-all";
      };

      # OnFailure sender: takes the failed unit name as $1, priority as $2.
      # Testable standalone: ntfy-failure-notify snapraidd.service urgent </dev/null
      failureNotify = pkgs.writeShellScriptBin "ntfy-failure-notify" ''
        set -eu
        unit="''${1:?failed unit name required}"
        prio="''${2:-urgent}"
        host="${config.networking.hostName}"
        ${ntfySend}/bin/ntfy-send ${cfg.failureNotify.topic} "$prio" <<EOF
        Service $unit failed on $host.
        Investigate: journalctl -u "$unit" -e
        EOF
      '';

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

        # ─── Filet OnFailure systemd → ntfy ───
        failureNotify = {
          enable = lib.mkEnableOption "systemd OnFailure safety net → ntfy";

          topic = lib.mkOption {
            type = lib.types.str;
            default = "nas-monitoring";
            description = "ntfy topic for unit-failure alerts";
          };

          units = lib.mkOption {
            type = lib.types.listOf lib.types.str;
            default = [];
            example = ["snapraidd" "samba-smbd" "immich-server"];
            description = ''
              Unit names to watch: each gets OnFailure= pointing at the
              ntfy-failure@ template. Use real unit names (systemctl
              list-units). Deliberately never include ntfy itself: if the
              notification server is down, the alert could not be sent
              anyway (chicken-and-egg; host-down blind spot is tracked
              separately).
            '';
          };
        };
      };

      config = lib.mkIf cfg.enable {
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

        users.groups.${cfg.group} = {};

        users.users.${cfg.user} = {
          isSystemUser = true;
          group = cfg.group;
          description = "ntfy push notification server";
        };

        environment.systemPackages = [
          pkgs.ntfy-sh # CLI for one-time provisioning and tests
          ntfySend
          failureNotify
        ];

        systemd.tmpfiles.rules = [
          "d ${cfg.stateDir} 0700 ${cfg.user} ${cfg.group} -"
        ];

        # All systemd.services definitions in ONE mkMerge: a single STATIC
        # key whose value is lazy. Two traps avoided at once:
        #  - never mix `systemd.services.X = …` (nested path) and
        #    `systemd.services = …` (direct assign) in the same attrset
        #    (plain-Nix duplicate attribute);
        #  - never put a genAttrs over an option as mkIf/mkMerge CONTENT:
        #    its keys get forced during module normalization → infinite
        #    recursion. As a VALUE inside this mkMerge, it is evaluated
        #    lazily at option-merge time, when reading the option is safe.
        systemd.services = lib.mkMerge [
          {
            # The upstream module relies on DynamicUser + StateDirectory,
            # incompatible with the one-time CLI provisioning of auth.db
            # (invariant #5). Run as the static user instead.
            ntfy-sh.serviceConfig = {
              DynamicUser = lib.mkForce false;
              ReadWritePaths = ["${cfg.stateDir}"];
            };
          }
          {
            # Native systemd directive (unitConfig): if the state dir lives
            # inside a mount, systemd derives the dependency from the path.
            ntfy-sh.unitConfig.RequiresMountsFor = ["${cfg.stateDir}"];
          }
          {
            # ─── OnFailure net: template unit ───
            # The failed unit's name arrives via the INSTANCE (%i), expanded
            # by systemd in directives only — hence the ExecStart argument,
            # never %i in a script body (the 31/10 bug: literal "%i").
            "ntfy-failure@" = lib.mkIf cfg.failureNotify.enable {
              description = "Alert ntfy: unit %i failed";
              # If the failure happens at boot, the alert waits for ntfy.
              after = ["network-online.target" "ntfy-sh.service"];
              wants = ["network-online.target"];
              # No OnFailure here: no recursion. If the send fails (ntfy
              # down), the oneshot just fails silently.
              serviceConfig = {
                Type = "oneshot";
                ExecStart = "${failureNotify}/bin/ntfy-failure-notify %i urgent";
              };
            };
          }
          # ─── OnFailure net: hooks on watched units ───
          # genAttrs as a mkMerge VALUE: lazy, evaluated at option-merge
          # time when reading cfg.failureNotify.units is safe.
          (lib.mkIf cfg.failureNotify.enable (
            lib.genAttrs cfg.failureNotify.units (_: {
              unitConfig.OnFailure = "ntfy-failure@%n.service";
            })
          ))
        ];
      };
    });
}
