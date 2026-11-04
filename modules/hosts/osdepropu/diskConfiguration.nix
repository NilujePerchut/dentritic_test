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
    fileSystems."/" =
      { device = "/dev/disk/by-uuid/3433981c-7b08-4b24-9099-542167aa8067";
        fsType = "ext4";
        options = ["rw" "relatime"];
      };
    };
  });
}
