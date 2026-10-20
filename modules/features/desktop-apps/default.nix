{
  self,
  moduleWithSystem,
  ...
}: {
  flake.nixosModules.desktop-apps = moduleWithSystem ({pkgs, ...}:
  {
    environment.systemPackages = with pkgs; [
      gimp
      onlyoffice-desktopeditors
      vlc
    ];
  });
}
