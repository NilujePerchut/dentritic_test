{
  self,
  inputs,
  moduleWithSystem,
  ...
}: {
  flake.nixosModules.tmux = moduleWithSystem ({pkgs, ...}: {config, ...}: let
    user = config.myConfig.user.name;
  in {
    home-manager.users.${user} = {
      xdg.configFile."tmux" = {
        source = "${inputs.niluje-configs}/tmux";
        recursive = true;
      };
      programs.tmux.enable = true;
    };
  });
}
