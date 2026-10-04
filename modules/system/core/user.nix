{
  self,
  inputs,
  moduleWithSystem,
  ...
}: {
  flake.nixosModules.user = moduleWithSystem ({inputs', ...}: let
  in {

    # Add the plugdev group
    users.groups.plugdev = {};

    users.users = {
      niluje = {
        isNormalUser = true;
        description = "niluje";
        extraGroups = [
          "root"
          "wheel"
          "plugdev"
          "dialout"
        ];
      };
    };
  });
}
