{
  self,
  moduleWithSystem,
  ...
}: {
  flake.nixosModules.prog = moduleWithSystem ({pkgs, ...}:
  {
    environment.systemPackages = with pkgs; [
      # Generic programmation tools
      rustup
      tig
      gcc
      gnumake
      cmake
      devenv
      python3
    ];
  });
}
