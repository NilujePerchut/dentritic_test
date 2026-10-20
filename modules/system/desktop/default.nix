{
  self,
  moduleWithSystem,
  ...
}: {
  flake.nixosModules.desktop = moduleWithSystem ({pkgs, lib, config, ...}: let
    modules = with self.nixosModules; [
      gnome
      term_emu
      browsers
    ];
    in {
    imports = modules;

    myConfig.desktop.enable = true;

    # Enable opengl
    hardware.graphics.enable = true;

    services.displayManager.gdm = {
      enable = true;
    };

    services.dbus = {
      enable = true;
      packages = [ pkgs.dconf ];
    };
    programs.dconf.enable = true;

    fonts.packages = with pkgs; [
      pkgs.nerd-fonts.noto
      pkgs.nerd-fonts.iosevka
    ];

    services.xserver.xkb = {
      layout = "fr";
      variant = "";
    };

    services.printing.enable = true;

    security.polkit.enable = true;

    services.hardware.bolt.enable = true;
  });
}
