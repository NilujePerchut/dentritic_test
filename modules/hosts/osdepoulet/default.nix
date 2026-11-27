{
  self,
  inputs,
  ...
}: {
  flake.nixosConfigurations.osdepoulet = inputs.nixpkgs.lib.nixosSystem {
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
        osdepouletConfiguration
        osdepouletDiskConfiguration
        bootloader-uefi
        core
        power
        bluetooth
        network
        cli-utils
        desktop
        desktop-apps
        nix-ld
        games
        print3d
        prog
        zsh
        elec
        hyprland
        niri
      ])
      ++ [{
        myConfig.power = {
          enable = true;
          cpuVendor = "amd";
        };
      }];
  };
}
