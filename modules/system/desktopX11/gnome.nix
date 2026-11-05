{
  self,
  moduleWithSystem,
  ...
}: {
  flake.nixosModules.gnome = moduleWithSystem ({pkgs, ...}:
    {
      services.desktopManager.gnome.enable = true;
      services.gnome.gnome-keyring.enable = true;
    });
}
