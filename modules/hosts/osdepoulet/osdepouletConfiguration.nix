{
  moduleWithSystem,
  ...
}: {
  flake.nixosModules.osdepouletConfiguration =
    moduleWithSystem
    ({...}: {config, pkgs, lib, ...}: {
      networking = {
        hostName = "osdepoulet";
        networkmanager.enable = true;
        firewall.enable = false;
        enableIPv6 = false;
      };

      # === Hibernation ===
      # Disk swap file (zram is excluded: a zram swap cannot hold the
      # hibernation image). 20 GiB > 16 GiB RAM.
      # Provision ONCE after first boot (runbook, cf. project invariant #5):
      #   sudo fallocate -l 20G /swapfile
      #   sudo chmod 600 /swapfile
      #   sudo mkswap /swapfile
      #   sudo swapon /swapfile
      # Then fill BOTH placeholders below:
      #   resume=        -> root partition UUID: lsblk -f /
      #   resume_offset= -> filefrag -v /swapfile | awk '$1=="0:" {print $4}'
      # (ext4 only; re-evaluate if root is btrfs/LUKS)
      swapDevices = [
        { device = "/swapfile"; size = 20 * 1024; }
      ];
      boot.kernelParams = [
        "resume=UUID=<ROOT-UUID-TO-FILL>"
        "resume_offset=<SWAPFILE-OFFSET-TO-FILL>"
      ];

      # Suspend on lid close, auto-hibernate after 45 min (battery drain
      # protection). GNOME "Hibernate" entry appears once CanHibernate=yes.
      services.logind.settings.Login = {
        lidSwitch = "suspend-then-hibernate";
        lidSwitchExternalPower = "suspend-then-hibernate";
      };

      nixpkgs.hostPlatform = lib.mkDefault "x86_64-linux";
      hardware.graphics.extraPackages = with pkgs; [ intel-media-driver ];
      hardware.enableRedistributableFirmware = lib.mkDefault true;
      hardware.cpu.amd.updateMicrocode = lib.mkDefault true;
      services.fwupd.enable = true;

      system.stateVersion = lib.mkForce "26.05";
    });
}

