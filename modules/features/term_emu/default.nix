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
      stTerm
    ];

    environment.systemPackages = with pkgs; [
      lxqt.qterminal
    ];
  });
}
