{
  self,
  inputs,
  moduleWithSystem,
  ...
}: {
  flake.nixosModules.term_emu = moduleWithSystem ({pkgs, ...}:
  {
    imports = with self.nixosModules; [
      kitty
      wezterm
    ];

    environment.systemPackages = with pkgs; [
      lxqt.qterminal
    ];
  });
}
