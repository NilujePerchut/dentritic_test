{
  self,
  moduleWithSystem,
  ...
}: {
  flake.nixosModules.nasCheck =
    moduleWithSystem
    ({pkgs, ...}: {config, lib, ...}: let
      cfg = config.services.nasCheck;
      send = config.services.ntfy.sendScript;

      # The shell logic lives in a sibling file, kept as plain shell:
      # the facade injects the runtime configuration (env vars) and
      # composes the final wrapper. NASCHECK_SEND (wrapper path) is
      # always exported; the sending policy is the separate NASCHECK_NOTIFY
      # boolean (option `notify`), overridable per-invocation with -n.
      script = builtins.readFile "${self}/modules/services/nas/nas-check.sh";

      nasCheck = pkgs.writeShellScriptBin "nas-check" ''
          # writeShellScriptBin runs no shellcheck at build time:
          # writeShellApplication's mandatory check chokes on the
          # non-ASCII message strings (accents, emoji) in the build
          # environment (no locale). We keep the same dependency
          # isolation with an explicit PATH.
          export PATH="${lib.makeBinPath [pkgs.curl pkgs.jq pkgs.systemd pkgs.gawk pkgs.inetutils]}:$PATH"

          # ─── Runtime configuration injected by the facade ───
          export NASCHECK_NETDATA_URL="${cfg.netdataUrl}"
          export NASCHECK_POOL_MOUNT="${cfg.poolMount}"
          export NASCHECK_POOL_WARN="${toString cfg.poolWarn}"
          export NASCHECK_POOL_CRIT="${toString cfg.poolCrit}"
          export NASCHECK_SNAPRAID_UNIT="${cfg.snapraiddUnit}"
          export NASCHECK_TOPIC="${cfg.topic}"
          # Always export the wrapper path: the script's notify() gates on
          # NASCHECK_NOTIFY (option `notify`), which the -n flag can raise
          # per-invocation even on a host with notify=false.
          export NASCHECK_SEND="${send}/bin/ntfy-send"
          export NASCHECK_NOTIFY="${if cfg.notify then "1" else "0"}"
          # Reusability: the digest adapts to what this host runs.
          export NASCHECK_CHECKS="${lib.concatStringsSep " " cfg.checks}"
          export NASCHECK_JOURNAL_HOURS="${toString cfg.journalHours}"
          export NASCHECK_BACKUPS="${config.services.stateBackup.backupsDir}"
          ${script}
      '';

    in {
      options.services.nasCheck = {
        enable = lib.mkEnableOption "Digest quotidien NAS (timer + commande nas-check)";

        notify = lib.mkEnableOption "senf digest to ntfy (disabled by default)";

        topic = lib.mkOption {
          type = lib.types.str;
          default = "nas-monitoring";
          description = "ntfy topic for the daily digest";
        };

        time = lib.mkOption {
          type = lib.types.str;
          default = "08:00";
          description = "Daily digest time (systemd OnCalendar syntax)";
        };

        poolMount = lib.mkOption {
          type = lib.types.str;
          default = "/mnt/mergerfs";
          description = "Pool mount to watch for fill level";
        };

        poolWarn = lib.mkOption {
          type = lib.types.int;
          default = 85;
          description = "Pool usage % reported as a problem";
        };

        poolCrit = lib.mkOption {
          type = lib.types.int;
          default = 95;
          description = "Pool usage % reported as critical";
        };

        snapraiddUnit = lib.mkOption {
          type = lib.types.str;
          default = "snapraidd";
          description = "snapraidd systemd unit name for journal inspection";
        };

        checks = lib.mkOption {
          type = lib.types.listOf (lib.types.enum ["netdata" "pool" "services" "snapraid" "backups"]);
          default = ["netdata" "pool" "services" "snapraid" "backups"];
          description = ''
            Groups run by the daily digest (nas-check all). Remove the
            groups irrelevant to this host — e.g. a host without snapraid
            or without a mergerfs pool. Groups can still be invoked
            individually regardless of this list.
          '';
        };

        journalHours = lib.mkOption {
          type = lib.types.int;
          default = 24;
          description = "Journal inspection window for the snapraid check (hours)";
        };

        netdataUrl = lib.mkOption {
          type = lib.types.str;
          default = "http://127.0.0.1:19999";
          description = "netdata API base URL";
        };
      };

      config = lib.mkIf cfg.enable {
        environment.systemPackages = [nasCheck];

        systemd.services.nas-check = {
          description = "NAS daily digest";
          after = ["network-online.target"];
          wants = ["network-online.target"];
          serviceConfig = {
            Type = "oneshot";
            # exit 1 = "problems found" is the script's documented contract,
            # not a service crash: without this, every digest with problems leaves
            # the unit in 'failed' state → the 'services' check counts it the next
            # day (self-referential false positive).
            SuccessExitStatus = [ 1 ];
          };
          script = "${nasCheck}/bin/nas-check all";
        };

        systemd.timers.nas-check = {
          description = "Run the NAS digest daily";
          wantedBy = ["timers.target"];
          timerConfig = {
            OnCalendar = cfg.time;
            # If the host was down at 08:00 (or boots after), run the
            # missed check at boot: the digest doubles as a signed boot.
            Persistent = true;
          };
        };
      };
    });
}
