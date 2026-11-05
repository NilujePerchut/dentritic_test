{
  self,
  inputs,
  ...
}: {
  flake.nixosModules.bootloader-legacy = {
    pkgs,
    lib,
    ...
  }: {
    boot = {
      loader = {
        timeout = 2;

        # BIOS/MBR
	grub = {
	  enable = true;
	  device = lib.mkDefault "/dev/sda";
	  configurationLimit = 5;
	};
      };
    kernelPackages = pkgs.linuxPackages_latest;
    initrd.availableKernelModules = [ "ata_piix" "ohci_pci" "ehci_pci" "ahci" "sd_mod" "sr_mod" ];
    initrd.kernelModules = [ ];
    kernelModules = [ ];
    extraModulePackages = [ ];
    };
  };
}
