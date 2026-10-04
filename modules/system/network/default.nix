{moduleWithSystem, ...}: {
  flake.nixosModules.network = moduleWithSystem ({...}: {config, ...}: {
    networking = {
      networkingmanager = {
        enable = true;
        dns = "none";
      };
      nameservers = [
       "1.1.1.1"
       "8.8.8.8"
      ];
      firewall.enable = false;
    };
    services.unbound.enable = true;
    systemd.services.NetworkManager-wait-online.enable = false;
  });
}
