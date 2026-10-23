{
  self,
  inputs,
  ...
}: {
  flake.nixosModules.hosts = {
    pkgs,
    lib,
    ...
  }: {
    networking.hosts = {
      "192.168.40.40" = ["osdegirouette"];
      "192.168.40.41" = ["osdepoulet"];
      "192.168.40.42" = ["osdeframboise"];
      "192.168.40.43" = ["osdeplacard"];
      "192.168.40.44" = ["osdemammouth"];
      "192.168.40.63" = ["vmshare"];
      "192.168.40.64" = ["printsrv"];
      "192.168.40.65" = ["vmshare2"];
      "192.168.40.254" = ["freebox"];
    };
  };
}
