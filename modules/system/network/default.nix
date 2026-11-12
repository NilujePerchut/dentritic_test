{moduleWithSystem, ...}: {
  flake.nixosModules.network = moduleWithSystem ({pkgs, ...}: {config, ...}: {
    networking = {
      networkmanager = {
        enable = true;
        dns = "none";
        plugins = with pkgs; [
          networkmanager-openvpn
          networkmanager-openconnect
        ];
      };
      nameservers = [
       "1.1.1.1"
       "8.8.8.8"
      ];
      firewall.enable = false;
      wireguard.enable = true;
    };

    environment.systemPackages = with pkgs; [
      networkmanagerapplet
      wirelesstools
      openconnect
      gpclient
      gpauth
    ];

    # Start nm-applet in non-GNOME (ie: i3)
    programs.nm-applet.enable = true;

    services.unbound.enable = true;
    systemd.services.NetworkManager-wait-online.enable = false;
  });
}
