{
  self,
  inputs,
  moduleWithSystem,
  ...
}: {
  flake.nixosModules.nvim = moduleWithSystem ({pkgs, ...}: {config, ...}: let
    user = config.myConfig.user.name;
  in {
    environment.systemPackages = with pkgs; [
      # Base programs
      neovim
      # Dependencies
      git
      gcc
      nodejs
      unzip
      ripgrep
      yarn
      fd
    ];

    home-manager.users.${user} = {
      xdg.configFile."nvim" = {
        source = "${inputs.niluje-configs}/nvim";
        recursive = true;
      };
      programs.neovim.enable = true;
    };
  });
}
