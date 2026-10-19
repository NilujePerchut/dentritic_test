{
  self,
  inputs,
  moduleWithSystem,
  ...
}: {
  flake.nixosModules.zellij = moduleWithSystem ({pkgs, ...}:
  {
    environment.systemPackages = with pkgs; [
      # Base programs
      zellij
    ];
    home-manager.users.niluje = {
      xdg.configFile."zellij" = {
        source = "${inputs.niluje-configs}/zellij";
        recursive = true;
      };
    };
  });
}
