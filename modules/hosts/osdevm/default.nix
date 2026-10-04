{
  self,
  inputs,
  ...
}: {
  flake.nixosConfigurations.osdevm = inputs.nixpkgs.lib.nixosSystem {
    system = "x86_64-linux";

    modules = with self.nixosModules;
      [
        osdevmConfiguration
        osdevmDiskConfiguration
        core
	nix-ld
	desktop
      ];
  };
}
