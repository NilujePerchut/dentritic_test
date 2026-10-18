{
  self,
  inputs,
  moduleWithSystem,
  ...
}: {
  flake.nixosModules.git = moduleWithSystem ({pkgs, ...}:
  {
    environment.systemPackages = with pkgs; [
      # Base programs
      git
      tig
    ];

    home-manager.users.niluje = {
      programs.git = {
        enable = true;
        settings = {
          user.name = "Niluje";
          user.email = "cdebarge@farialis.net";
          init.defaultBranch = "main";
        };
      };
    };
  });
}
