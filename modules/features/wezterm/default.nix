{
  self,
  inputs,
  moduleWithSystem,
  ...
}: {
  flake.nixosModules.wezterm = moduleWithSystem ({pkgs, ...}:
  {
    environment.systemPackages = with pkgs; [
      # Base programs
      wezterm
    ];

    home-manager.users.niluje = {
      xdg.configFile."wezterm/wezterm.lua".source = "${inputs.niluje-configs}/wezterm.lua";
    };
  });
}
