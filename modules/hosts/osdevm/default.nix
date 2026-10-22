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
      power
      bluetooth
      nix-ld
      network
      desktop
      desktop-apps
      cli-utils
      prog
      elec
    ]) ++ [{
      myConfig.power = {
        enable = true;
        cpuVendor = "intel";
      };
    }];
  };
}
