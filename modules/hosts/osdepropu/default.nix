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
      osdepropuConfiguration
      osdepropuDiskConfiguration
      core
      bootloader-legacy
      desktopX11
      power
      bluetooth
      nix-ld
      network
      cli-utils
      prog
    ]) ++ [{
      boot.kernelParams = [
        "nox2apic"              # avoid the x2APIC path where the IPI gets lost
        "rcupdate.rcu_normal=1" # never use expedited grace periods
        "clocksource=acpi_pm"   # NEM mis-calibrates TSC
      ];

      myConfig.power = {
        enable = true;
        cpuVendor = "intel";
      };
      myConfig.user = {
        name = "cdebarge";
	      description = "Cédric Debarge";
	      gitName = "Cédric Debarge";
	      gitEmail = "cedric.debarge@ion-x.eu";
      };

      # Only applied at first user creation; use mkpasswd -m yescrypt to generate
      users.users.cdebarge.initialHashedPassword = "$y$j9T$REPLACE_ME";

      services.unbound.enable = inputs.nixpkgs.lib.mkForce false;
    }];
  };
}
