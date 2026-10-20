{
  self,
  moduleWithSystem,
  ...
}: {
  flake.nixosModules.browsers = moduleWithSystem({...}:
  {
    imports = with self.nixosModules; [
      brave
      firefox
    ];
  });
}
