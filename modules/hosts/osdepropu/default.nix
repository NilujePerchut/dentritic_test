{
  self,
  inputs,
  ...
}: {
  flake.nixosConfigurations.osdepropu = inputs.nixpkgs.lib.nixosSystem {
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
      bootloader-legacy
      power
      bluetooth
      nix-ld
      network
      cli-utils
      prog
    ]) ++ [{
      myConfig.power = {
        enable = true;
        cpuVendor = "intel";
      };
    }] ++ {[
      myConfig.user = {
        name = "cdebarge";
	description = "Cédric Debarge";
	gitName = "Cédric Debarge";
	gitEmail = "cedric.debarge@ion-x.eu";
      };

      # Only applied ar first user creation; use mkpasswd -m yescrypt to generate
      users.users.cdebarge.initialHashPassword = "$y$j9T$REPLACE_ME";
    ]};
  };
}
