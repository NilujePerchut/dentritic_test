{
  self,
  moduleWithSystem,
  ...
}: {
  flake.nixosModules.niri = moduleWithSystem
    ({pkgs, ...}: {config, lib, ...}: {
      # Shared shell: Noctalia is imported by both compositors so that
      # enabling either one installs and configures the common bar.
      imports = [ self.nixosModules.noctalia ];

      options.myConfig.niri = {
        enable = lib.mkEnableOption ''
          Niri scrollable-tiling Wayland compositor. Registers a GDM
          session next to GNOME; GDM stays the session manager.
        '';
      };

      config = lib.mkIf config.myConfig.niri.enable {
        myConfig.noctalia.enable = true;

        # Native nixpkgs option; also provides the GDM session file.
        programs.niri.enable = true;

        environment.systemPackages = with pkgs; [
          # Xwayland for niri: the official pattern is a standalone
          # satellte compositor, spawned per-session via home-manager.
          xwayland-satellite

          # Polkit agent for non-GNOME sessions
          lxqt.lxqt-policykit

          # Wayland session utilities (shared with the hyprland module)
          grim
          slurp
          wl-clipboard
          swaybg
        ];
      };
    });
}
