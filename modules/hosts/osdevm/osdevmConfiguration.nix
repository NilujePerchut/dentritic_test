{...}: {
  flake.nixosModules.osdevmConfiguration = {pkgs, ...}: {
    networking = {
      hostName = "osdevm";
    };
    environment.systemPackages = with pkgs; [
    ];
    swapDevices = [
    ];
    nixpkgs.hostPlatform = lib.mkDefault "x86_64-linux";
    virtualisation.virtualbox.guest.enable = true;
  };
}
