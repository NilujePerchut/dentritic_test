{
  description = "nix flake config for osdevm";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-26.05";

    # flake parts
    flake-parts.url = "github:hercules-ci/flake-parts";
    import-tree.url = "github:vic/import-tree";

  };

  outputs = inputs: inputs.flake-parts.lib.mkFlake {inherit inputs;} (inputs.import-tree ./modules);
}
