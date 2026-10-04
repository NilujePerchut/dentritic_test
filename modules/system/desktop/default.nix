{
  self,
  moduleWithSystem,
  ...
}: {
  flake.nixosModules.desktop = moduleWithSystem ({pkgs, ...}: let
    modules = with self.nixosModules; [
      core
      network
      audio
      gnome
    ];
    in {
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
      enable = true;
      layout = "fr";
      variant = "";
    };

    services.printing.enable = true;

    security.polkit.enable = true;
  });
}
