{
  self,
  inputs,
  ...
}: {
  flake.nixosConfigurations.osdepokemon = inputs.nixpkgs.lib.nixosSystem {
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
        osdepokemonConfiguration
        osdepokemonDiskConfiguration
        bootloader-uefi
        core
        power
        bluetooth
        network
        cli-utils
        desktop
        desktop-apps
        browsers
      ])
      ++ [{
        myConfig.power = {
          enable = true;
          cpuVendor = "intel";
        };
        myConfig.user = {
          name = "adidi";
          description = "Adidi";
        };
      }];
  };
}
