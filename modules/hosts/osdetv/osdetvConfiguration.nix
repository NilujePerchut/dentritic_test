{
  self,
  moduleWithSystem,
  ...
}: {
  flake.nixosModules.osdetvConfiguration =
    moduleWithSystem
    ({...}: {config, pkgs, lib, ...}: {
      networking = {
        hostName = "osdetv";
        networkmanager.enable = true;
        enableIPv6 = false;
        firewall.enable = false;
        interfaces.eno1.wakeOnLan.enable = true;
      };

      swapDevices = [];

      nixpkgs.hostPlatform = lib.mkDefault "x86_64-linux";

      # Temporary: Immich 2.x is EOL (CVE-2026-59258, CVE-2026-82272) and 3.x
      # only lands in NixOS 26.11. Accepted risk: LAN-only deployment, no
      # public exposure. TODO: remove this entry when upgrading to 26.11.
      nixpkgs.config.permittedInsecurePackages = [
        "immich-2.7.5"
      ];

      # NOTE: the immich database role and ownership are provisioned
      # manually (see project runbook), because the upstream module does
      # not derive them from services.immich.user and ensureDBOwnership
      # only supports role name == database name:
      #   CREATE ROLE niluje WITH LOGIN;
      #   ALTER DATABASE immich OWNER TO niluje;

      services.nas = {
        enable = true;
        pool.mountPoint = "/mnt/mergerfs";
        dataDisks = [
          {mountPoint = "/mnt/data1";}
          {mountPoint = "/mnt/data2";}
          {mountPoint = "/mnt/data3";}
        ];
        parityDisks = ["/mnt/parity1" "/mnt/parity2"];
        snapraidd = {
          enable = true;
          port = 7627;
          listenAll = true;
          smart.ignore = [ "* Spin_Up_Time Raw_Read_Error_Rate" ];
          notify = {
            resultLevel = "warning";
            # %s title, %t tag, %n ntfy priority (substituted by snapraidd
            # before executing), full report on stdin.
            resultCmd = ''NTFY_TITLE="%s" NTFY_TAG="%t" ${config.services.ntfy.sendScript}/bin/ntfy-send nas-alerts "%n"'';
          };
        };
      };

      # ── Rescue access (incident 2026-11-18/20) ──
      # Emergency mode spawns a sulogin shell that REQUIRES the root
      # password. Without one, a stuck boot is a locked door: no
      # console, no SSH. The hash lives in sops (never the plaintext).
      # neededForUsers = true is NOT optional: user activation runs
      # BEFORE the regular sops service, so without this flag the
      # hash file would not exist when /etc/shadow is written. Once
      # written into /etc/shadow, the hash survives any later boot,
      # including emergency mode (root fs intact: only a DATA mount
      # failed — nofail keeps the system up for everything else).
      sops.secrets."root-hash" = {
        sopsFile = "${self}/secrets/root-hash.sops.yaml";
        key = "root-hash";
        neededForUsers = true;
      };

      users.users.root.hashedPasswordFile = config.sops.secrets."root-hash".path;

      services.ntfy.enable = true;
      services.ntfy.failureNotify = {
        enable = true;
        units = [ "snapraidd" "samba-smbd" "postgresql" "immich-server"
                  "immich-machine-learning" "redis-immich" "statebackup" ];
      };

      # Dedicated group for reading the ntfy token (0440): members are the
      # snapraidd worker (drops to nobody at runtime, uid 65534) and the
      # netdata agent. Replaces the previous nogroup-wide convention.
      users.groups.nas-alerts = { };
      users.users.nobody.extraGroups = [ "nas-alerts" ];
      sops.secrets."ntfy-token" = {
        group = "nas-alerts";
        mode = "0440";
      };

      services.smb = {
        enable = true;
        workgroup = "WORKGROUP";
        serverString = "osdetv";
        # Samba password is provided by sops
        users.niluje.passwordFile = config.sops.secrets."samba-niluje".path;
        shares = {
          partage = {
            path = "/mnt/mergerfs/partage";
            owner = "niluje";
            group = "users";
            validUsers = ["niluje"];
          };
        };
      };

      services.immichNas = {
        enable = true;
        machineLearning = true;
        dataDir = "/mnt/mergerfs/server/immich";
        user = "niluje";
        group = "users";
        stateBackup.enable = true;
      };

      services.netdataNas = {
        enable = true;
        notifications = {
          topic = "nas-monitoring";
          tokenFile = config.sops.secrets."ntfy-token".path;
        };

        # No swap on this host : the stock used_swap
        # alert fires a boot-time false positive on an empty system.swap
        # chart. Disable it via the [health] pattern filter; remove this
        # line when permanent swap lands.

        # !net_drops — INTERIM, décision 03/11/2026 :
        # RX drops constants 0,5/s = broadcasts Realtek 0x8899 (MAC 54:07:7d:20:b3:3b,
        # likely player Freebox), 22% du trafic RX.
        settings.health."enabled alarms" = "!used_swap !net_drops *";
      };

      services.nasCheck = {
        enable = true;
        notify = true;
      };

      services.nasCheck.smartDisks = [
        "/dev/disk/by-label/disk1"
        "/dev/disk/by-label/disk2"
        "/dev/disk/by-label/disk3"
        "/dev/disk/by-label/disk4"
        "/dev/disk/by-label/disk5"
      ];
      services.nasCheck.checks = ["netdata" "pool" "services" "snapraid"
                                  "backups" "smart"];

      services.navidromeNas = {
        enable = true;
        musicFolder = "/mnt/mergerfs/partage/music";
      };

      services.stateBackup = {
        enable = true;
        systemdDeps = ["postgresql.service"];
      };

      services.ntfy.stateBackup.enable = true;
    });
}
