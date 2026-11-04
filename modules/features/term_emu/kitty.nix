{
  self,
  inputs,
  moduleWithSystem,
  ...
}: {
  flake.nixosModules.kitty = moduleWithSystem ({pkgs, ...}: {config, ...} : let
    user = config.myConfig.user.name;
  in {
    environment.systemPackages = with pkgs; [
      # Base programs
      kitty
    ];

    home-manager.users.${user} = {
      xdg.configFile."kitty/kitty.conf".source = "${inputs.niluje-configs}/kitty.conf";
    };
  });
}
