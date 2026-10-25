{
  moduleWithSystem,
  ...
}: {
  flake.nixosModules.osdetvConfiguration =
    moduleWithSystem
    ({...}: {pkgs, lib, ...}: {
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
          lanCidr = "192.168.40.0/24";
        };
      };

      services.smb = {
        enable = true;
        workgroup = "WORKGROUP";
        serverString = "osdetv";
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
      };
    });
}
