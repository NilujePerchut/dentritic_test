{
  self,
  moduleWithSystem,
  ...
}: {
  flake.nixosModules.prog = moduleWithSystem ({pkgs, ...}:
  {
    imports = [
      ({lib, config, ...}: {
        environment.systemPackages = with pkgs; [
          # Generic programmation tools
          rustup
          tig
          gcc
          gnumake
          cmake
          devenv
          python3
        ] ++ lib.optionals config.myConfig.desktop.enable [
          meld
          putty
          emacs-gtk
        ];
      })
    ];
  });
}
