{
  flake.nixosModules.homepage =
    { config, lib, ... }:
    {
      config = {
        services.homepage-dashboard = {
          enable = true;

          allowedHosts = "localhost:8082,127.0.0.1:8082,192.168.40.43:8082";

          bookmarks = [
            {
              Developer = [
                {
                  Github = [
                    {
                      abbr = "GH";
                      icon = "github.png";
                      href = "https://github.com/NilujePerchut/";
                    }
                  ];
                }
                {
                  "Nixos package search" = [
                    {
                      abbr = "NPS";
                      href = "https://search.nixos.org/packages";
                    }
                  ];
                }
                {
                  MyNixos = [
                    {
                      abbr = "MN";
                      href = "https://mynixos.com/";
                    }
                  ];
                }
              ];
            }
          ];

          services = [
            {
              Media = [
                {
                  Immich = {
                    description = "Photo library";
                    icon = "immich.png";
                    href = "http://192.168.40.66:2283";
                  };
                }
                {
                  Navidrome = {
                    description = "Music streaming";
                    icon = "navidrome.png";
                    href = "http://192.168.40.66:4533";
                  };
                }
              ];
            }
            {
              Monitoring = [
                {
                  Netdata = {
                    description = "NAS metrics and alerts";
                    icon = "netdata.png";
                    href = "http://192.168.40.66:19999";
                  };
                }
                {
                  ntfy = {
                    description = "Push notifications";
                    icon = "ntfy.png";
                    href = "http://192.168.40.66:2586";
                  };
                }
                {
                  SnapRAID = {
                    description = "Parity sync and scrub (Commander UI)";
                    icon = "ugreen-nas.png";
                    href = "http://192.168.40.66:7627";
                  };
                }
              ];
            }
            {
              Tools = [
                {
                  SolidCraft = {
                    href = "http://192.168.40.43:8095";
                    icon = "mdi-cube-outline";
                    description = "Parametric 3D CAD (browser)";
                  };
                }
              ];
            }
            {
              Home = [
                {
                  Freebox = {
                    description = "Freebox admin page";
                    icon = "freebox-revolution.png";
                    href = "https://192.168.40.254";
                  };
                }
              ];
            }
          ];

          widgets = [
            {
              resources = {
                cpu = true;
                disk = "/";
                memory = true;
              };
            }
            {
              datetime = {
                locale = "fr";
                text_size = "xl";
              };
            }
            {
              search = {
                provider = "google";
                target = "_blank";
                focus = true;
                showSearchSuggestions = true;
              };
            }
          ];
        };
      };
    };
}
