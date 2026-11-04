{
  self,
  inputs,
  moduleWithSystem,
  ...
}: {
  flake.nixosModules.git = moduleWithSystem ({pkgs, ...}: {config, ...}: let
    user = config.myConfig.user.name;
  in {
    environment.systemPackages = with pkgs; [
      # Base programs
      git
      tig
    ];

    home-manager.users.${user} = {
      programs.git = {
        enable = true;
        settings = {
          user.name = config.myConfig.user.gitName;
          user.email = config.myConfig.user.gitEmail;
          init.defaultBranch = "main";
        };
      };
    };
  });
}
