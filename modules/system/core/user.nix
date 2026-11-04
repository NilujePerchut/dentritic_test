{
  self,
  inputs,
  moduleWithSystem,
  ...
}: {
  flake.nixosModules.user = moduleWithSystem ({...}: {config, ...}: let
    user = config.myConfig.user.name;
  in {
    # Add the plugdev group
    users.groups.plugdev = {};

    users.users.${user} = {
      isNormalUser = true;
      description = config.myConfig.user.description;
      extraGroups = [
        "wheel"
        "plugdev"
        "dialout"
        "networkmanager"
      ];
    };

    # Home-manager stuff
    home-manager.users.${user} = {
      home.stateVersion = "26.05";
    };
  });
}
