{
  self,
  moduleWithSystem,
  ...
}: {
  flake.nixosModules.elec = moduleWithSystem ({pkgs, ...}:
  {
    environment.systemPackages = with pkgs; [
      kicad
      putty
    ];
  });
}
