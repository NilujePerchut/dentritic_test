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
        device = "/dev/disk/by-uuid/ae029aac-253d-498f-9801-db28f79c397f";
        fsType = "ext4";
        options = ["rw" "relatime"];
      };

      "/boot" = {
        device = "/dev/disk/by-uuid/8428-760A";
        fsType = "vfat";
        options = [ "fmask=0077" "dmask=0077" ];
      };
    };
  });
}
