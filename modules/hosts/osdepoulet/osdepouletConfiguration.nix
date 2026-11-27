{
  moduleWithSystem,
  ...
}: {
  flake.nixosModules.osdepouletConfiguration =
    moduleWithSystem
    ({...}: {config, pkgs, lib, ...}: {
      networking = {
        hostName = "osdepoulet";
        networkmanager.enable = true;
        firewall = {
            enable = true;
            allowedTCPPorts = [ 22 ];
        };
        enableIPv6 = false;
      };

      # Suspend on lid close, auto-hibernate after 45 min (battery drain
      # protection). GNOME "Hibernate" entry appears once CanHibernate=yes.
      services.logind.settings.Login = {
        lidSwitch = "suspend-then-hibernate";
        lidSwitchExternalPower = "suspend-then-hibernate";
      };

      nixpkgs.hostPlatform = lib.mkDefault "x86_64-linux";
      hardware.enableRedistributableFirmware = lib.mkDefault true;
      hardware.cpu.amd.updateMicrocode = lib.mkDefault true;
      services.fwupd.enable = true;

      # Custom cursor theme (Nord variant of the capitaine fork)
      environment.systemPackages = [ pkgs.capitaine-cursors-themed ];
      environment.sessionVariables.XCURSOR_THEME = "Capitaine Cursors (Nord)";

      myConfig.gnome.gsconnect = true;

      myConfig.hyprland.enable = true;
      myConfig.niri.enable = true;

      system.stateVersion = lib.mkForce "26.05";
    });
}

