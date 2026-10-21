{
  self,
  moduleWithSystem,
  ...
}: {
  flake.nixosModules.elec = moduleWithSystem ({pkgs, ...}:
  {
    imports = with self.nixosModules; [
      qmk-dev
    ];
    environment.systemPackages = with pkgs; [
      kicad
      putty
    ];
  });
}
