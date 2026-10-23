{...}: {
  flake.nixosModules.osdeplacardConfiguration = {pkgs, lib, ...}: {
    networking = {
      hostName = "osdeplacard";
      networkmanager.enable = true;
      enableIPv6 = false;
      firewall.enable = false;
    };
    environment.systemPackages = with pkgs; [
    ];
    swapDevices = [
    ];
    nixpkgs.hostPlatform = lib.mkDefault "x86_64-linux";
    system.stateVersion = lib.mkForce "24.05";
  };
}
