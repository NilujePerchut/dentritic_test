{
  self,
  moduleWithSystem,
  ...
}: {
  flake.nixosModules.hyprland = moduleWithSystem
    ({pkgs, ...}: {config, lib, ...}: {
      # Shared shell: Noctalia is imported by both compositors so that
      # enabling either one installs and configures the common bar.
      imports = [ self.nixosModules.noctalia ];

      options.myConfig.hyprland = {
        enable = lib.mkEnableOption ''
          Hyprland Wayland compositor. Registers a GDM session next to
          GNOME; GDM stays the session manager (decided 27/11/2026).
        '';
      };

      config = lib.mkIf config.myConfig.hyprland.enable {
        myConfig.noctalia.enable = true;

        programs.hyprland = {
          enable = true;
          xwayland.enable = true;
          portalPackage = pkgs.xdg-desktop-portal-hyprland;
        };

        environment.systemPackages = with pkgs; [
          # Polkit agent: GDM does not spawn GNOME's agent outside the
          # GNOME session; started per-session via home-manager.
          hyprpolkitagent

          # Wayland session utilities
          hyprpicker
          grim
          slurp
          wl-clipboard
          swaybg
        ];
      };
    });
}
