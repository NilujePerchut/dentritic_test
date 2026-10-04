{
  self,
  moduleWithSystem,
  ...
}: {
  flake.nixosModules.gnome = moduleWithSystem ({pkgs, ...}: let
    modules = with self.nixosModules; [
    ];
    in {
      services.desktopManager.gnome.enable = true;
      services.gnome.gnome-keyring.enable = true;
    });
}
