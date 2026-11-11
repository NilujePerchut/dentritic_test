{
  self,
  moduleWithSystem,
  ...
}: {
  flake.nixosModules.osdepokemonDiskConfiguration =
    moduleWithSystem
    ({...}: {lib, ...}: {
      boot.initrd.availableKernelModules = [ "xhci_pci" "thunderbolt" "nvme" "usb_storage" "sd_mod" ];
      boot.initrd.kernelModules = [ ];
      boot.kernelModules = [ "kvm-intel" ];
      boot.extraModulePackages = [ ];

      fileSystems."/" =
        { device = "/dev/disk/by-uuid/b62c007d-3f50-475d-91f8-43a9bb126bf6";
          fsType = "ext4";
        };

      fileSystems."/boot" =
        { device = "/dev/disk/by-uuid/3220-9D4F";
          fsType = "vfat";
          options = [ "fmask=0077" "dmask=0077" ];
        };

      swapDevices =
        [ { device = "/dev/disk/by-uuid/59efd330-3c2e-4fe3-a358-33094d042369"; }
        ];
      networking.useDHCP = lib.mkDefault true;
  });
}
