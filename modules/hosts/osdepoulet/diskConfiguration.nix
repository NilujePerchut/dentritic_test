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

      # Swap partition (hibernation): dedicated 40 GiB partition after root
      # (nvme0n1p3). Deterministic resume: header at block 0, no resume_offset.
      # 40 GiB = 32 GiB RAM x 1.25 (hibernation image must fit in swap).
      swapDevices = [
        { device = "/dev/disk/by-uuid/ed10283c-4d82-480b-861d-930f0832e15c"; }
      ];

      boot.kernelParams = [ "resume=UUID=ed10283c-4d82-480b-861d-930f0832e15c" ];

      networking.useDHCP = lib.mkDefault true;

      # Home Manager must not touch the existing Firefox profile
      # (managed profile "niluje" would shadow the legacy "default" one).
      home-manager.users.niluje.programs.firefox.enable = lib.mkForce false;
  });
}
