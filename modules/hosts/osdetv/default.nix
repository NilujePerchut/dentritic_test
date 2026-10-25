{
  self,
  inputs,
  ...
}: {
  flake.nixosConfigurations.osdetv = inputs.nixpkgs.lib.nixosSystem {
    system = "x86_64-linux";

    modules =
      [
        inputs.home-manager.nixosModules.home-manager
        {
          home-manager.useGlobalPkgs = true;
          home-manager.useUserPackages = true;
          home-manager.extraSpecialArgs = {inherit inputs;};
        }
      ]
      ++ (with self.nixosModules; [
        osdetvConfiguration
        osdetvDiskConfiguration
        core
        nix-ld
        network
        cli-utils
        nas
        samba
        immich
      ]);
  };
}
