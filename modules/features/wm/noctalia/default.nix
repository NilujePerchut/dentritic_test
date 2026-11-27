{
  self,
  moduleWithSystem,
  ...
}: {
  flake.nixosModules.noctalia = moduleWithSystem
    ({pkgs, ...}: {config, lib, ...}: {
      options.myConfig.noctalia = {
        enable = lib.mkEnableOption ''
          Noctalia desktop shell (bar, notifications, launcher, OSD).
          Works on both Hyprland and Niri sessions; started per-session
          via the compositor config (home-manager), never at boot.
        '';
      };

      config = lib.mkIf config.myConfig.noctalia.enable {
        environment.systemPackages = [ pkgs.noctalia-shell ];

        services.upower.enable = true;
        services.power-profiles-daemon.enable = true;
      };
    });
}
