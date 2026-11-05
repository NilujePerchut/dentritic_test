{...}: {
  flake.nixosModules.osdepropuConfiguration = {pkgs, lib, ...}: {
    networking = {
      hostName = "osdepropu";
    };
    environment.systemPackages = with pkgs; [ ];
    swapDevices = [ ];
    nixpkgs.hostPlatform = lib.mkDefault "x86_64-linux";
    virtualisation.virtualbox.guest.enable = true;
  };
}
