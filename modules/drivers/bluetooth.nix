{
  self,
  moduleWithSystem,
  ...
}: {
  flake.nixosModules.bluetooth = moduleWithSystem ({...}:
  {
    imports = [
      ({lib, config, ...}: {
        hardware.bluetooth = {
          enable = true;
          powerOnBoot = true;
        };

        services.blueman.enable = lib.mkIf config.myConfig.desktop.enable true;
      })
    ];
  });
}
