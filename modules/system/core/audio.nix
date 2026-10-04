{
  self,
  moduleWithSystem,
  ...
}: {
  flake.nixosModules.audio = moduleWithSystem ({pkgs, ...}: let
    modules = with self.nixosModules; [
    ];
    in {
      services.pulseaudio.enable = false;
      security.rtkit.enable = false;
      services.pipewire = {
        enable = true;
        alsa.enable = true;
        alsa.support32Bit = true;
        pulse.enable = true;
        jack.enable = true;
      };
    });
}
