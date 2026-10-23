{
  self,
  moduleWithSystem,
  ...
}: {
  flake.nixosModules.print3d = moduleWithSystem ({pkgs, unfreePkgs, ...}:
  {
    imports = [
      ({lib, config, ...}: {
        assertions = [
          {
            assertion = config.myConfig.desktop.enable;
            message = "The print3d module needs the desktop module";
          }
        ];
      })
    ];

    environment.systemPackages = [
      pkgs.openscad
      pkgs.freecad
      unfreePkgs.bambu-studio
    ];
  });
}
