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
      services.rtkit.enable = false;
      services.pipewire = {
        enable = true;
        alsa.enable = true;
        alsa.support32Bit.enable = true;
        pulse.enable = true;
        jack.enable = true;
      };
    });
}
