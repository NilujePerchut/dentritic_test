{
  self,
  moduleWithSystem,
  ...
}: {
  flake.nixosModules.games = moduleWithSystem ({pkgs, unfreePkgs, ...}:
  {
    imports = [
      ({lib, config, ...}: {
        assertions = [
          {
            assertion = config.myConfig.desktop.enable;
            message = "The 'game' module requiers a desktop.";
          }
        ];
      })
    ];

    programs.steam = {
      enable = true;
      gamescopeSession.enable = true;
    };

    programs.gamemode.enable = true;

    environment.systemPackages = [
      unfreePkgs.steam
      pkgs.protonup-ng
      pkgs.heroic
    ];
  });
}
