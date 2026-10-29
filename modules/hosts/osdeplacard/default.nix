{
  self,
  inputs,
  ...
}: {
  flake.nixosConfigurations.osdeplacard = inputs.nixpkgs.lib.nixosSystem {
    system = "x86_64-linux";

    modules = [
      inputs.sops-nix.nixosModules.sops
      inputs.home-manager.nixosModules.home-manager
      {
        home-manager.useGlobalPkgs = true;
        home-manager.useUserPackages = true;
        home-manager.extraSpecialArgs = {inherit inputs;};
      }
    ] ++ (with self.nixosModules; [
      osdeplacardConfiguration
      osdeplacardDiskConfiguration
      core
      power
      nix-ld
      network
      cli-utils
      sops
    ]) ++ [{
      myConfig.power = {
        enable = true;
        cpuVendor = "intel";
      };
    }];
  };
}
