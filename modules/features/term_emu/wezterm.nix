{
  self,
  inputs,
  moduleWithSystem,
  ...
}: {
  flake.nixosModules.wezterm = moduleWithSystem ({pkgs, ...}: {config, ...}: let
    user = config.myConfig.user.name;
  in {
    environment.systemPackages = with pkgs; [
      # Base programs
      wezterm
    ];

    home-manager.users.${user} = {
      xdg.configFile."wezterm/wezterm.lua".source = "${inputs.niluje-configs}/wezterm.lua";
    };
  });
}
