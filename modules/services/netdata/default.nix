# Facade for Netdata monitoring with ntfy alert routing.
# Registered like the other service facades (samba/immich/ntfy):
# a flake-parts module exposing flake.nixosModules.netdata via moduleWithSystem.
# The NixOS facade namespace is services.netdataNas (upstream keeps services.netdata).
# Design follows project invariants:
#   - generic facade, no NAS coupling in defaults
#   - state lives in /var/lib/netdata (regenerable, not backed up)
#   - token read at runtime -> no restart on rotation
{
  self,
  moduleWithSystem,
  ...
}: {
  flake.nixosModules.netdata =
    moduleWithSystem
    ({pkgs, ...}: {config, lib, ...}: let
      cfg = config.services.netdataNas;

      # health_alarm_notify.conf is a shell fragment sourced by netdata's
      # alarm-notify at alert time: the token is read from the sops runtime
      # path on every notification, never at build time.
      healthAlarmNotify = pkgs.writeText "health_alarm_notify.conf" ''
        # No sendmail on this host; email is the fallback of last resort.
        SEND_EMAIL="NO"

        # ntfy token, read at runtime (rotation requires no restart/rebuild)
        NTFY_ACCESS_TOKEN="$(<${cfg.notifications.tokenFile})"

        DEFAULT_RECIPIENT_NTFY="${cfg.notifications.url}/${cfg.notifications.topic}"
        role_recipients_ntfy[sysadmin]="${cfg.notifications.url}/${cfg.notifications.topic}"
        role_recipients_ntfy[domainadmin]="${cfg.notifications.url}/${cfg.notifications.topic}"
      '';
    in {
      options.services.netdataNas = with lib; {
        enable = mkEnableOption "Netdata monitoring with ntfy notifications";

        package = mkOption {
          type = types.package;
          default = pkgs.netdata;
          description = "Netdata package to use.";
        };

        # Short retention, capped disk footprint (state is disposable).
        retention = mkOption {
          type = types.str;
          default = "5d";
          description = "Metric retention passed to the dbengine [db] section.";
        };

        dbDiskSpace = mkOption {
          type = types.str;
          default = "1024";
          description = "Max MiB of dbengine disk space in /var/lib/netdata.";
        };

        notifications = {
          topic = mkOption {
            type = types.str;
            description = "ntfy topic for health alerts.";
          };

          url = mkOption {
            type = types.str;
            default = "http://localhost:2586";
            description = "ntfy server base URL.";
          };

          tokenFile = mkOption {
            type = types.path;
            description = ''
              Runtime path of the ntfy token (sops). Must be readable by
              the netdata user — e.g. sops.secrets.<name>.group = "nogroup";
              mode 0440 with netdata added to group nogroup.
            '';
          };
        };

        # Extra alarm definitions, e.g. healthRules."smart-temp.conf" = '''...''';
        healthRules = mkOption {
          type = types.attrsOf types.lines;
          default = {};
          description = "Additional health.d alarm files (name -> content).";
        };

        settings = mkOption {
          type = types.attrsOf types.attrs;
          default = {};
          description = "Extra netdata.conf sections, merged with the facade defaults.";
        };
      };

      config = lib.mkIf cfg.enable {
        services.netdata = {
          enable = true;
          # ndsudo (SUID helper) lets the agent run smartctl/nvme without extra wiring.
          package = cfg.package.override {withNdsudo = true;};
          extraNdsudoPackages = with pkgs; [
            smartmontools
            nvme-cli
          ];
          config =
            {
              db = {
                mode = "dbengine";
                retention = cfg.retention;
                "dbengine multihost disk space" = cfg.dbDiskSpace;
              };
            }
            // cfg.settings;
          configDir =
            {
              "health_alarm_notify.conf" = healthAlarmNotify;
            }
            // lib.mapAttrs'
              (name: content:
                lib.nameValuePair "health.d/${name}" (pkgs.writeText name content))
              cfg.healthRules;
        };

        # The sops token is exposed group=nogroup mode 0440 (same convention as
        # snapraidd): grant the netdata agent read access via group membership.
        users.users.netdata.extraGroups = ["nogroup"];
      };
    });
}

# ---------------------------------------------------------------------------
# HOST osdetv — registration:
# wherever samba/immich/ntfy nixosModules are imported on the host, add:
#
#   imports = [ self.nixosModules.netdata ];   # next to self.nixosModules.samba etc.
#
# and enable:
#
#   services.netdataNas = {
#     enable = true;
#     notifications = {
#       topic = "nas-monitoring";
#       tokenFile = config.sops.secrets."ntfy-token".path;
#     };
#     # rodage: keep defaults first, add SMART/disk alarms after the first week
#     # healthRules."disks.conf" = ''' … seuils relevés depuis le dashboard … ''';
#   };
#
# Provisioning (once, CLI runbook — invariant n°5): nothing new to provision.
# The existing ntfy token already has access 'nas-*' rw, which covers the
# nas-monitoring topic. Subscribe the Android app to "nas-monitoring" (F-Droid,
# token auth) to receive the alerts.
#
# Verification after `sudo nixos-rebuild switch --flake .#osdetv`:
#   systemctl status netdata
#   journalctl -u netdata -e
#   curl -s localhost:19999/api/v1/info | head
#   sudo -u netdata smartctl -H /dev/sdX        # ndsudo path sanity check
#   # end-to-end alert test (validates send_custom arg order on your netdata):
#   sudo -u netdata ${pkgs.netdata}/libexec/netdata/plugins.d/alarm-notify.sh test sysadmin
#
# Points to verify on the first build (nixpkgs 26.05):
#   - the "withNdsudo" override argument name of the netdata package
#   - the "retention" key of the [db] section on your netdata version
# ---------------------------------------------------------------------------
