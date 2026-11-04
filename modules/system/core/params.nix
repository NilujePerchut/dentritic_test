{
  self,
  moduleWithSystem,
  ...
}: {
  flake.nixosModules.params = {lib, ...}: {
    options.myConfig = {
      desktop.enable = lib.mkEnableOption "desktop env";

      # Main user of the host, consumed by the user and home-manager modules
      user = {
        name = lib.mkOption {
          type = lib.types.nonEmptyStr;
          default = "niluje"; # keeps existing hosts unchanged
          description = "Main user name of the host";
        };

        description = lib.mkOption {
          type = lib.types.str;
          default = "niluje";
          description = "User description (gecos)";
        };

        # Git identity used by the git feature
        gitName = lib.mkOption {
          type = lib.types.str;
          default = "Niluje";
          description = "Git user.name for commits";
        };

        gitEmail = lib.mkOption {
          type = lib.types.str;
          default = "cdebarge@farialis.net";
          description = "Git user.email for commits";
        };
      };

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
