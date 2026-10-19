{
  self,
  inputs,
  moduleWithSystem,
  ...
}: {
  flake.nixosModules.tmux = moduleWithSystem ({pkgs, ...}:
  {
    environment.systemPackages = with pkgs; [
      # Base programs
       tmux
    ];
    home-manager.users.niluje = {
      xdg.configFile."tmux" = {
        source = "${inputs.niluje-configs}/tmux";
        recursive = true;
      };
      programs.tmux.enable = true;
    };
  });
}
