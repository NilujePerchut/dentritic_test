{
  self,
  moduleWithSystem,
  ...
}: {
  flake.nixosModules.desktopX11 = moduleWithSystem ({pkgs, lib, config, ...}: let
    modules = with self.nixosModules; [
      desktopX11-xfce
      term_emu
      browsers
    ];
    in {
    imports = modules;

    services.xserver = {
      enable = true;
      xkb = {
        layout = "fr";
        variant = "";
      };

      displayManager.lightdm = {
        enable = true;
      };

      desktopManager.xfce.enable = true;
    };

    services.displayManager.defaultSession = "xfce";
    hardware.graphics.enable = true;

    services.dbus = {
      enable = true;
      packages = [ pkgs.dconf ];
    };
    programs.dconf.enable = true;

    fonts.packages = with pkgs; [
      nerd-fonts.noto
      nerd-fonts.iosevka
    ];

    services.printing.enable = true;
    security.polkit.enable = true;
  });
}
