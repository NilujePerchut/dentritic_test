{...}: {
  flake.nixosModules.osdevmConfiguration = {pkgs, ...}: {
    networking = {
      hostName = "osdevm";
    };
    environment.systemPackages = with pkgs; [
    ];
    swapDevices = [
    ];
  };
}
