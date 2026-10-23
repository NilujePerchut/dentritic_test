{
  self,
  inputs,
  moduleWithSystem,
  ...
}: {
  flake.nixosModules.user-niluje = moduleWithSystem ({inputs', ...}: let
    user = "niluje";
  in {
    # Add the plugdev group
    users.groups.plugdev = {};

    users.users.${user} = {
      isNormalUser = true;
      description = "niluje";
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
