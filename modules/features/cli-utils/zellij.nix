{
  self,
  inputs,
  moduleWithSystem,
  ...
}: {
  flake.nixosModules.zellij = moduleWithSystem ({pkgs, ...}: {config, ...}: let
    user = config.myConfig.user.name;
  in {
    environment.systemPackages = with pkgs; [
      # Base programs
      zellij
    ];
    home-manager.users.${user} = {
      xdg.configFile."zellij" = {
        source = "${inputs.niluje-configs}/zellij";
        recursive = true;
      };
    };
  });
}
