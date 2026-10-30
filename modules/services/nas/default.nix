{
  self,
  moduleWithSystem,
  ...
}: {
  flake.nixosModules.nas =
    moduleWithSystem
    ({pkgs, ...}: {config, lib, ...}: let
      cfg = config.services.nas;

      snapraidSmart = pkgs.snapraid.overrideAttrs (old: {
        version = "15.0";
        src = pkgs.fetchFromGitHub {
          owner = "amadvance";
          repo = "snapraid";
          tag = "v15.0";
          hash = "sha256-ftmmd8cHeggj2PLSqyJvOly/kUBFPXYaqpHwxwE/uDc=";
        };
        nativeBuildInputs = (old.nativeBuildInputs or []) ++ [pkgs.autoreconfHook];
        configureFlags = (old.configureFlags or []) ++ [
          "--with-smartctl=${pkgs.smartmontools}/bin/smartctl"
        ];
      });

      # Real ELF in a clean derivation: snapraidd spawns tasks without a
      # shell and rejects shebang scripts; smartctl is compiled in as an
      # absolute path (--with-smartctl above), so the wrapper's PATH tweak
      # is redundant here.
      snapraidElf = pkgs.runCommand "snapraid-elf" {} ''
        install -Dm555 ${snapraidSmart}/bin/.snapraid-wrapped $out/bin/snapraid
      '';

      snapraidd = pkgs.stdenv.mkDerivation {
        pname = "snapraidd";
        version = "2.1";
        src = pkgs.fetchzip {
          url = "https://github.com/amadvance/snapraid-daemon/releases/download/v2.1/snapraid-daemon-2.1.tar.gz";
          sha256 = "sha256-e3uLEGbEP44j/aXhe1uqDc0N6+UQu092mF0XGcrLP1s=";
        };
        buildInputs = [pkgs.zip];
        configureFlags = [
          # snapraidd's task spawner refuses shell-script binaries: its
          # internal validation aborts with EINVAL as soon as it sees a
          # shebang, without ever calling execve. The nixpkgs snapraid
          # package wraps bin/snapraid in a bash script (smartmontools
          # PATH), so we expose the real ELF at a stable path. A symlink
          # won't do: the daemon opens the target with O_NOFOLLOW.
          "--with-snapraid=${snapraidElf}/bin/snapraid"
        ];
        meta = with lib; {
          description = "SnapRAID daemon & web UI (REST API, job scheduler)";
          homepage = "https://www.snapraid.it/ui";
          license = licenses.gpl3;
          platforms = platforms.linux;
        };
      };

      #(ex: /mnt/data1 → mnt-data1.mount)
      mountUnit = mp: "${builtins.replaceStrings ["/"] ["-"] mp}.mount";
      allMounts = (map (d: d.mountPoint) cfg.dataDisks) ++ cfg.parityDisks;

      listenLine = if cfg.snapraidd.listenAll
        then "net_port = ${toString cfg.snapraidd.port}"
        else "net_port = 127.0.0.1:${toString cfg.snapraidd.port}";

      parityLines = lib.imap1 (i: p: "${if i == 1 then "parity" else "${toString i}-parity"} ${p}/snapraid.parity") cfg.parityDisks;
      # snapraid.conf syntax is `data <name> <path>`; a bare `d<N> <path>`
      # is rejected with "Invalid command" and silently breaks every
      # maintenance run.
      diskLines = lib.concatStringsSep "\n" (lib.imap1 (i: d: "data d${toString i} ${d.mountPoint}") cfg.dataDisks);      contentLines = builtins.concatStringsSep "\n"
        ((map (d: "content ${d.mountPoint}/snapraid.content") cfg.dataDisks)
         ++ (lib.optional (cfg.parityDisks != []) "content ${lib.head cfg.parityDisks}/snapraid.content"));
    in {
      options.services.nas = {
        enable = lib.mkEnableOption "NAS storage: MergerFS pool + SnapRAID parity + snapraidd";

        pool = {
          mountPoint = lib.mkOption {
            type = lib.types.str;
            default = "/mnt/pool";
            description = "MergerFS pool mount point";
          };
          uid = lib.mkOption {
            type = lib.types.int;
            default = 1000;
            description = "MergerFS pool UID";
          };
          gid = lib.mkOption {
            type = lib.types.int;
            default = 100;
            description = "MergerFS pool GID";
          };
        };

        dataDisks = lib.mkOption {
          type = lib.types.listOf (lib.types.submodule {
            options.mountPoint = lib.mkOption {
              type = lib.types.str;
              description = "Data disk mount point";
            };
          });
          default = [];
          description = "Data disks. The order sets the identifiers d1..dn : do not reorder an existing array.";
        };

        parityDisks = lib.mkOption {
          type = lib.types.listOf lib.types.str;
          default = [];
          description = "Parity disk mount point";
        };

        snapraidd = {
          enable = lib.mkEnableOption "Daemon snapraidd (web UI SnapRAID)";

          port = lib.mkOption {
            type = lib.types.port;
            default = 7627;
            description = "Snapraidd UI port";
          };

          listenAll = lib.mkOption {
            type = lib.types.bool;
            default = false;
            description = "Listen on all interfaces. localhost only otherwise";
          };

          lanCidr = lib.mkOption {
            type = lib.types.str;
            default = "192.168.40.0/24";
            description = "Allowed network";
          };

          fullConfigAccess = lib.mkOption {
            type = lib.types.bool;
            default = true;
            description = "Full access to the config UI";
          };

          maintenance = {
            schedule = lib.mkOption {
              type = lib.types.str;
              default = "02:00";
              description = "Check window sync+scrub+rapport (HH:MM ou 'Mon 03:00, Thu 04:00')";
            };
            scrubPercentage = lib.mkOption {
              type = lib.types.float;
              default = 0.7;
              description = "Array fraction checked by scrub after each sync (0 = scrub disabled)";
            };
            scrubOlderThan = lib.mkOption {
              type = lib.types.int;
              default = 10;
              description = "Do not scrub blocs earlier than N days";
            };
            prehash = lib.mkEnableOption "sync with --prehash";
            preventTruncations = lib.mkEnableOption "sync abort files that are truncated to 0";
          };

          smart = {
            probeMinutes = lib.mkOption {
              type = lib.types.int;
              default = 3;
              description = "SMART check period (0 = disabled)";
            };
            ignore = lib.mkOption {
              type = lib.types.listOf lib.types.str;
              default = [];
              example = ["* Spin_Up_Time Raw_Read_Error_Rate"];
              description = "SMART Attributs ignored per disk ('*' = all)";
            };
          };

          notify = {
            resultLevel = lib.mkOption {
              type = lib.types.enum ["info" "warning" "error" "critical"];
              default = "warning";
              description = "notify_result lower level trigger";
            };
            resultCmd = lib.mkOption {
              type = lib.types.nullOr lib.types.str;
              default = null;
              description = "Result command (placeholders %s %l %n %t %h %c, on stdin) — ex: curl ntfy";
            };
            startCmd = lib.mkOption {
              type = lib.types.nullOr lib.types.str;
              default = null;
              description = "Start command";
            };
          };
        };

        syncTimer = {
          enable = lib.mkEnableOption "SnapRAID sync Timer (default: off)";

          schedule = lib.mkOption {
            type = lib.types.str;
            default = "weekly";
            description = "SnapRAID sync Planification (OnCalendar)";
          };
        };
      };

      config = lib.mkIf cfg.enable {
        programs.fuse.userAllowOther = true;

        environment.systemPackages = with pkgs; [
          snapraidSmart
          mergerfs
          mergerfs-tools
          smartmontools
          gptfdisk
          parted
        ];

        fileSystems."${cfg.pool.mountPoint}" = {
          device = lib.concatStringsSep ":" (map (d: d.mountPoint) cfg.dataDisks);
          fsType = "mergerfs";
          options = [
            "defaults"
            "allow_other"
            "moveonenospc=1"
            "func.getattr=newest"
            "fsname=mergerfs"
            "uid=${toString cfg.pool.uid}"
            "gid=${toString cfg.pool.gid}"
            "umask=002"
            "x-mount.mkdir"
          ];
        };

        systemd.tmpfiles.rules =
          map (d: "d ${d.mountPoint} 0755 ${toString cfg.pool.uid} ${toString cfg.pool.gid} -")
            cfg.dataDisks
          ++ map (p: "d ${p} 0755 ${toString cfg.pool.uid} ${toString cfg.pool.gid} -")
               cfg.parityDisks;

        environment.etc."snapraid.conf".text = ''
          ${lib.concatStringsSep "\n" parityLines}
          ${diskLines}
          ${contentLines}
          blocksize 256
          autosave 500
        '';

        environment.etc."snapraidd.conf".text = ''
          net_enabled = 1
          ${listenLine}
          net_acl = +127.0.0.1,+${cfg.snapraidd.lanCidr}
          net_config_full_access = ${if cfg.snapraidd.fullConfigAccess then "1" else "0"}
          sys_log_retention_days = 120
          net_web_root = ${snapraidd}/share/snapraidd/commander.zip

          # == Native maintenance : sync → scrub → rapport ──
          maintenance_schedule = ${cfg.snapraidd.maintenance.schedule}
          scrub_percentage = ${toString cfg.snapraidd.maintenance.scrubPercentage}
          scrub_older_than = ${toString cfg.snapraidd.maintenance.scrubOlderThan}
          ${lib.optionalString cfg.snapraidd.maintenance.prehash "sync_prehash = 1"}
          ${lib.optionalString cfg.snapraidd.maintenance.preventTruncations "sync_prevent_truncations = 1"}

          # == SMART continuous checks ==
          probe_interval_minutes = ${toString cfg.snapraidd.smart.probeMinutes}
          ${lib.optionalString (cfg.snapraidd.smart.ignore != [])
            "sys_smartignore = ${lib.concatStringsSep ", " cfg.snapraidd.smart.ignore}"}

          # == Notifications ==
          notify_result_level = ${cfg.snapraidd.notify.resultLevel}
          ${lib.optionalString (cfg.snapraidd.notify.resultCmd != null)
            "notify_result = ${cfg.snapraidd.notify.resultCmd}"}
          ${lib.optionalString (cfg.snapraidd.notify.startCmd != null)
            "notify_start = ${cfg.snapraidd.notify.startCmd}"}
        '';

        systemd.services.snapraidd = lib.mkIf cfg.snapraidd.enable {
          description = "SnapRAID Daemon (web UI)";
          wantedBy = ["multi-user.target"];
          after = ["network-online.target" "local-fs.target"];
          wants = ["network-online.target" "local-fs.target"] ++ map mountUnit allMounts;
          serviceConfig = {
            User = "root";
            Group = "root";
            Type = "forking";
            Restart = "on-failure";
            RestartSec = "5";
            PIDFile = "/run/snapraidd.pid";
            ExecStart = "${snapraidd}/bin/snapraidd -c /etc/snapraidd.conf -C /etc/snapraid.conf";
            ExecReload = "${pkgs.util-linux}/bin/kill -HUP $MAINPID";
            Nice = "19";
            IOSchedulingClass = "idle";
          };
        };

        systemd.services.snapraid-sync = lib.mkIf cfg.syncTimer.enable {
          description = "SnapRAID sync";
          serviceConfig = {
            Type = "oneshot";
            ExecStart = "${snapraidSmart}/bin/snapraid -c /etc/snapraid.conf sync";
            Nice = "19";
            IOSchedulingClass = "idle";
          };
          after = map mountUnit allMounts;
          wants = map mountUnit allMounts;
        };

        systemd.timers.snapraid-sync = lib.mkIf cfg.syncTimer.enable {
          description = "Planification du sync SnapRAID";
          wantedBy = ["timers.target"];
          timerConfig.OnCalendar = cfg.syncTimer.schedule;
        };
      };
    });
}
