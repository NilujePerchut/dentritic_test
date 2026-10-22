{
  self,
  moduleWithSystem,
  ...
}: {
  flake.nixosModules.params = {lib, ...}: {
    options.myConfig = {
      desktop.enable = lib.mkEnableOption "desktop env";

      power = {
        enable = lib.mkEnableOption "Power management (laptop)";
        cpuVendor = lib.mkOption {
          type = lib.types.enum [ "intel" "amd" ];
          description = "CPU vendor (will select thermald vs amd_pstate)";
        };
      };
    };
  };
}
