{
  self,
  inputs,
  moduleWithSystem,
  ...
}: {
  flake.nixosModules.cli-utils = moduleWithSystem ({pkgs, ...}:
  {
    imports = with self.nixosModules; [
      nvim
      zsh
      git
      zellij
      tmux
    ];

    environment.systemPackages = with pkgs; [
      # Base programs
      htop
      dust
      killall
      silver-searcher
    ];
  });
}
