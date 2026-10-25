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
    });
}
