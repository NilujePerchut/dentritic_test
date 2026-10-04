{inputs, ...}: {
  perSystem = {system, ...}: {
    _module.args.unfreePkgs = import inputs.nixpkgs {
      inherit system;
      config.allowUnfree = true;
    };
  };
  flake.nixosModules.nix = {...}: {
    nix = {
      settings = {
        experimental-features = [
          "nix-command"
          "flakes"
        ];
      };
      nixPath = ["nixpkgs=${inputs.nixpkgs}"];
      gc = {
        automatic = true;
        dates = "daily";
        options = "--delete-older-than 5d";
      };
    };
    nixpkgs = {
      config = {
        allowUnfree = true;
      };
    };
  };
}
