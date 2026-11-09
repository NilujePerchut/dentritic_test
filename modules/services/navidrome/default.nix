{
  self,
  moduleWithSystem,
  ...
}: {
  flake.nixosModules.navidrome =
    moduleWithSystem
    ({pkgs, ...}: {config, lib, ...}: let
      cfg = config.services.navidromeNas;
    in {
      options.services.navidromeNas = {
        enable = lib.mkEnableOption "Navidrome music streaming (Subsonic API + web player)";

        musicFolder = lib.mkOption {
          type = lib.types.str;
          default = "/mnt/mergerfs/music";
          description = "Music library on the mergerfs pool. Read-only for Navidrome.";
        };

        dataDir = lib.mkOption {
          type = lib.types.str;
          default = "/var/lib/navidrome";
          description = "Navidrome application state (DB, caches). Deliberately on the local system disk, NOT on the pool: SQLite on mergerfs (HDD + FUSE) is slow and had permission issues, and the DB is regenerable from the library by a rescan — documented exception to architecture invariant #4";
        };

        port = lib.mkOption {
          type = lib.types.port;
          default = 4533;
          description = "Navidrome port (web UI + Subsonic API)";
        };
      };

      config = lib.mkIf cfg.enable {
        services.navidrome = {
          enable = true;
          user = "niluje";
          group = "users";
          settings = {
            Address = "0.0.0.0";
            Port = cfg.port;
            MusicFolder = cfg.musicFolder;
            DataFolder = cfg.dataDir;
            EnableInsightsCollector = false;
          };
        };

        # Note: no tmpfiles rule needed for dataDir — the upstream module
        # already provisions DataFolder/CacheFolder via its own tmpfiles
        # (navidromeDirs.conf) and StateDirectory=/var/lib/navidrome.

        # ── Ordering & mounts: the service must not start before tmpfiles
        # has created its state directories nor before mergerfs is up,
        # otherwise the first SQLite open fails with ENOENT.
        systemd.services.navidrome = {
          after = ["systemd-tmpfiles-setup.service"];
          wants = ["systemd-tmpfiles-setup.service"];
          unitConfig.RequiresMountsFor = ["${cfg.dataDir}" "${cfg.musicFolder}"];
        };

        networking.firewall.allowedTCPPorts = [cfg.port];
      };
    });
}
