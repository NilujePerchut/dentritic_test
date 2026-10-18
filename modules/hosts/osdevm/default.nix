{
  self,
  inputs,
  ...
}: {
  flake.nixosConfigurations.osdevm = inputs.nixpkgs.lib.nixosSystem {
    system = "x86_64-linux";

    modules = [
      inputs.home-manager.nixosModules.home-manager
      {
        home-manager.useGlobalPkgs = true;
        home-manager.useUserPackages = true;
        home-manager.extraSpecialArgs = {inherit inputs;};
      }
    ] ++ (with self.nixosModules; [
      osdevmConfiguration
      osdevmDiskConfiguration
      core
      nix-ld
      network
      desktop
      nvim
      zsh
    ]);
  };
}
