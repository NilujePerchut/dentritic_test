{
  self,
  moduleWithSystem,
  ...
}: {
  flake.nixosModules.gnome = moduleWithSystem ({pkgs, ...}:
    { config, lib, ... }: let
      user = config.myConfig.user.name;
    in {
      options.myConfig.gnome.gsconnect = lib.mkEnableOption ''
        GSConnect (KDE Connect protocol for GNOME): install the
        extension, enable it for the main user and open the
        KDE Connect firewall ports (1714-1764 TCP/UDP)
      '';

      config = lib.mkMerge [
        {
          services.desktopManager.gnome.enable = true;
          services.gnome.gnome-keyring.enable = true;
        }

        (lib.mkIf config.myConfig.gnome.gsconnect {
          # Extension (nixpkgs package, managed; not the imperative
          # extensions.gnome.org install)
          environment.systemPackages = [ pkgs.gnomeExtensions.gsconnect ];

          # KDE Connect protocol: TCP 1714-1764 (connections),
          # UDP 1714-1764 (discovery/broadcast)
          networking.firewall.allowedTCPPortRanges = [ { from = 1714; to = 1764; } ];
          networking.firewall.allowedUDPPortRanges = [ { from = 1714; to = 1764; } ];

          # Auto-enable the extension for the main user (system dconf is
          # already enabled by the desktop module)
          home-manager.users.${user}.dconf.settings = {
            "org/gnome/shell" = {
              enabled-extensions = [ "gsconnect@andyholmes.github.io" ];
            };
          };
        })
      ];
    });
}
