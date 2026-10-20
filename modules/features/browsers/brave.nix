{
  self,
  moduleWithSystem,
  ...
}: {
  flake.nixosModules.brave = moduleWithSystem({pkgs, ...}:
  {
    environment.systemPackages = with pkgs; [ brave ];
  });
}
