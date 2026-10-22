{
  self,
  inputs,
  moduleWithSystem,
  ...
}: {
  flake.nixosModules.kitty = moduleWithSystem ({pkgs, ...}:
  {
    environment.systemPackages = with pkgs; [
      # Base programs
      kitty
    ];

    home-manager.users.niluje = {
      xdg.configFile."kitty/kitty.conf".source = "${inputs.niluje-configs}/kitty.conf";
    };
  });
}
