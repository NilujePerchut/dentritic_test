{
  self,
  moduleWithSystem,
  ...
}: {
  flake.nixosModules.osdetvDiskConfiguration =
    moduleWithSystem
    ({...}: {lib, ...}: {
      boot.initrd.availableKernelModules = ["xhci_pci" "ahci" "nvme" "usb_storage" "usbhid" "sd_mod"];
      boot.initrd.kernelModules = [];
      boot.kernelModules = [];
      boot.extraModulePackages = [];

      fileSystems = {
        "/" = {
          device = "/dev/disk/by-uuid/a7555ade-5f62-40f7-82a5-5c69e9e024cd";
          fsType = "ext4";
        };

        "/boot" = {
          device = "/dev/disk/by-uuid/2DF6-9E2F";
          fsType = "vfat";
          options = ["fmask=0077" "dmask=0077"];
        };

        # Data disks (NAS)
        "/mnt/data1" = {device = "/dev/disk/by-label/disk1"; fsType = "ext4";};
        "/mnt/data2" = {device = "/dev/disk/by-label/disk2"; fsType = "ext4";};
        "/mnt/data3" = {device = "/dev/disk/by-label/disk3"; fsType = "ext4";};

        # Parity disks (SnapRAID)
        "/mnt/parity1" = {device = "/dev/disk/by-label/disk4"; fsType = "ext4";};
        "/mnt/parity2" = {device = "/dev/disk/by-label/disk5"; fsType = "ext4";};
      };

      networking.useDHCP = lib.mkDefault true;
    });
}
