{
  self,
  moduleWithSystem,
  ...
}: {
  flake.nixosModules.params = {lib, ...}: {
    options.myConfig.desktop.enable = lib.mkEnableOption "desktop env";
  };
}
