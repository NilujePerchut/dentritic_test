{
  self,
  moduleWithSystem,
  ...
}: {
  flake.nixosModules.osdeplacardDiskConfiguration = moduleWithSystem ({...}: {lib, ...}: {
    boot.initrd.availableKernelModules = ["xhci_pci" "ahci" "nvme" "usbhid" "sd_mod"];
    boot.initrd.kernelModules = [];
    boot.kernelModules = ["kvm-intel"];
    boot.extraModulePackages = [];

    fileSystems = {
      "/" = {
        device = "/dev/disk/by-uuid/c1568df2-629e-4beb-a632-94c7cffddc01";
        fsType = "ext4";
      };

      "/boot" = {
        device = "/dev/disk/by-uuid/E8CA-F526";
        fsType = "vfat";
        options = ["fmask=0077" "dmask=0077"];
      };

      "/mnt/data" = {
        device = "/dev/disk/by-uuid/cdea5b60-306d-471d-95d2-85248880bbbf";
        fsType = "ext4";
        options = ["defaults"];
      };
    };

    networking.useDHCP = lib.mkDefault true;
  });
}
