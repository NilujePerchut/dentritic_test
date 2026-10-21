{
  self,
  moduleWithSystem,
  ...
}: {
  flake.nixosModules.qmk-dev = moduleWithSystem ({pkgs, unfreePkgs, ...}:
  {
    services.udev = {
      extraRules = ''
        # Rules for keyboard web flashing and live training
        KERNEL=="hidraw*", ATTRS{idVendor}=="16c0", MODE="0664", GROUP="plugdev"
        KERNEL=="hidraw*", ATTRS{idVendor}=="3297", MODE="0664", GROUP="plugdev"
        # PICkit 2
        ATTRS{idVendor}=="04d8", ATTRS{idProduct}=="0033", MODE="0660", GROUP="plugdev"
        # PICkit 3
        ATTRS{idVendor}=="04d8", ATTRS{idProduct}=="900a", MODE="0660", GROUP="plugdev"
        # PKOB
        ATTRS{idVendor}=="04d8", ATTRS{idProduct}=="8107", MODE="0660", GROUP="plugdev"
      '';

      packages = with pkgs; [
        picoprobe-udev-rules
      ] ++ [
        unfreePkgs.via
        unfreePkgs.saleae-logic-2
      ];
    };

    environment.systemPackages = with pkgs; [
      qmk
      gcc-arm-embedded
      usbutils
    ] ++ [
      unfreePkgs.via
      unfreePkgs.saleae-logic-2
    ];
  });
}
