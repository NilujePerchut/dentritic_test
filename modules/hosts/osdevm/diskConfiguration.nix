{
  self,
  moduleWithSystem,
  ...
}: {
  flake.nixosModules.osdevmDiskConfiguration = moduleWithSystem ({
    pkgs,
    self,
    inputs,
    ...
  }: {
    fileSystems = {
      "/" = {
        device = "/dev/disk/by-uuid/565ec039-2e0f-4312-88eb-922d31a551c1";
        fsType = "ext4";
        options = ["rw" "relatime"];
      };

      "/boot" = {
        device = "/dev/disk/by-uuid/A519-4AF8";
        fsType = "vfat";
        options = [ "fmask=0077" "dmask=0077" ];
      };
    };
  });
}
