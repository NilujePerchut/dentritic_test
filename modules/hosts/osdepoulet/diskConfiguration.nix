{
  self,
  moduleWithSystem,
  ...
}: {
  flake.nixosModules.osdepouletDiskConfiguration =
    moduleWithSystem
    ({...}: {lib, ...}: {

      boot.initrd.availableKernelModules = [ "nvme" "xhci_pci" "thunderbolt" "usb_storage" "sd_mod" ];
      boot.initrd.kernelModules = [ ];
      boot.kernelModules = [ "kvm-amd" ];
      boot.extraModulePackages = [ ];

      fileSystems."/" =
        { device = "/dev/disk/by-uuid/eb7034bb-d629-44d4-889b-844d7082871a";
          fsType = "ext4";
        };

      fileSystems."/boot" =
        { device = "/dev/disk/by-uuid/8384-B7E4";
          fsType = "vfat";
          options = [ "fmask=0022" "dmask=0022" ];
        };

      swapDevices = [ ];

      networking.useDHCP = lib.mkDefault true;
  });
}
