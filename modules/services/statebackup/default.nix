{
  self,
  moduleWithSystem,
  ...
}: {
  flake.nixosModules.statebackup =
    moduleWithSystem
    ({pkgs, ...}: {config, lib, ...}: let
      cfg = config.services.stateBackup;

      # The shell logic lives in a sibling file, kept as plain shell:
      # the facade injects the runtime configuration (env vars) and
      # composes the final wrapper (same pattern as nas-check).
      script = builtins.readFile "${self}/modules/services/statebackup/statebackup.sh";

      # Job registry: the facade options "compiled" into shell functions.
      # Written to the Nix store: immutable, hash-identified with the
      # config that produced every backup run.
      jobsFile = pkgs.writeText "statebackup-jobs.sh" (lib.concatStringsSep "\n"
        (lib.mapAttrsToList (name: job: ''
          # ── job: ${name} ──
          job_${name}_dump() {
            ${job.dumpCommand}
          }
          job_${name}_restore() {
            ${job.restoreCommand}
          }
          job_${name}_units() {
            echo "${lib.concatStringsSep " " job.stopUnits}"
          }
        '') cfg.jobs));

      # self.shortRev is null on a dirty checkout: "dirty" is the honest value.
      gitRev =
        if (self.shortRev or null) != null
        then self.shortRev
        else "dirty";

      nasBackup = pkgs.writeShellScriptBin "nas-backup" ''
        export PATH="${lib.makeBinPath (with pkgs; [coreutils gnused gnugrep gawk systemd sudo postgresql sqlite])}:$PATH"
        export STATEBACKUP_ROOT="${cfg.backupsDir}"
        export STATEBACKUP_JOBS_FILE="${jobsFile}"
        export STATEBACKUP_ALL_JOBS="${lib.concatStringsSep " " (lib.attrNames cfg.jobs)}"
        export STATEBACKUP_GIT_REV="${gitRev}"
        ${script}
      '';
    in {
      options.services.stateBackup = {
        enable = lib.mkEnableOption "Service state backups with GFS rotation (nas-backup CLI + timer)";

        backupsDir = lib.mkOption {
          type = lib.types.str;
          default = "/mnt/mergerfs/server/backups";
          description = "Root directory for the GFS grid (daily/weekly/monthly/yearly per job)";
        };

        startAt = lib.mkOption {
          type = lib.types.str;
          default = "*-*-* 01:00:00";
          description = ''
            systemd OnCalendar for the backup run. Must complete BEFORE the
            snapraidd sync so each nightly dump is parity-protected on its
            first night (02:00 on osdetv).
          '';
        };

        jobs = lib.mkOption {
          type = lib.types.attrsOf (lib.types.submodule {
            options = {
              stopUnits = lib.mkOption {
                type = lib.types.listOf lib.types.str;
                default = [];
                description = "Units to stop before restore and restart after";
              };
              dumpCommand = lib.mkOption {
                type = lib.types.str;
                description = "Shell snippet writing the dump to $1 (tmp path). Runs as root.";
              };
              restoreCommand = lib.mkOption {
                type = lib.types.str;
                description = "Shell snippet restoring from $1. Runs as root, units already stopped.";
              };
            };
          });
          default = {};
          description = "Backup jobs, one subdirectory per job. Services facades contribute via mkMerge.";
        };
      };

      config = lib.mkIf cfg.enable {
        # Manual CLI: same engine as the timer (single code path).
        environment.systemPackages = [nasBackup];

        systemd.services.statebackup = {
          description = "Service state backups (GFS rotation)";
          # A backup written to a demounted pool would be a false success:
          # systemd refuses to run the service at all instead.
          unitConfig.RequiresMountsFor = ["${cfg.backupsDir}"];
          serviceConfig.Type = "oneshot";
          # Dumps ALL jobs: one unit to monitor, one OnFailure hook.
          script = "${nasBackup}/bin/nas-backup dump";
        };

        systemd.timers.statebackup = {
          description = "Nightly state backups (before the snapraid sync)";
          wantedBy = ["timers.target"];
          timerConfig = {
            OnCalendar = cfg.startAt;
            # Rattrape une nuit éteinte (cohérent nas-check / snapraidd).
            Persistent = true;
          };
        };
      };
    });
}
