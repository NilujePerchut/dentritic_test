{
  self,
  moduleWithSystem,
  ...
}: {
  flake.nixosModules.power = moduleWithSystem ({...}:
  {
    imports = [
      ({lib, config, ...}: let
        cfg = config.myConfig.power;
      in {
        config = lib.mkIf cfg.enable {
          powerManagement.enable = true;

          services.power-profiles-daemon.enable = true;

          services.thermald.enable = lib.mkIf (cfg.cpuVendor == "intel") true;
        };
      })
    ];
  });
}
