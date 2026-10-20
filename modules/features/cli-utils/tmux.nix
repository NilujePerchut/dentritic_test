{
  self,
  inputs,
  moduleWithSystem,
  ...
}: {
  flake.nixosModules.tmux = moduleWithSystem ({pkgs, ...}:
  {
    home-manager.users.niluje = {
      xdg.configFile."tmux" = {
        source = "${inputs.niluje-configs}/tmux";
        recursive = true;
      };
      programs.tmux.enable = true;
    };
  });
}
