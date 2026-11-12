{
  self,
  inputs,
  moduleWithSystem,
  ...
}: {
  flake.nixosModules.desktopX11-i3 = moduleWithSystem ({pkgs, ...}: {config, lib, ...}: let
    user = config.myConfig.user.name;

    consoleLauncher = pkgs.writeShellScriptBin "console_launcher" ''
    #!/usr/bin/env bash

    # Launch the first existing terminal from the list below
    # If the TERMINAL environment variable is set and the binary exists, use it
    # instead (e.g. TERMINAL=st for low-perf VMs)

    TERMINALS="wezterm kitty qterminal gnome-terminal xfce4-terminal"

    if [ -n "$TERMINAL" ] && command -v "$TERMINAL" > /dev/null 2>&1; then
        exec "$TERMINAL" "$@"
    fi

    for term in $TERMINALS; do
        command -v "$term" > /dev/null 2>&1 && { exec "$term" "$@"; }
    done
    '';

  in {

    environment.systemPackages = with pkgs; [
      dmenu
      i3lock
      polkit_gnome
      consoleLauncher
      nemo
      feh
    ];

    services.xserver.windowManager.i3.enable = true;

    home-manager.users.${user} = {
      xsession.enable = true;
      # Keep HM's session script out of the NixOS wrapper's way: the
      # session-wrapper execs ~/.xsession (if executable) BEFORE the
      # registered session command — HM's script always execs i3 and
      # would hijack every session (xfce included)
      xsession.scriptPath = ".xsession-hm";
      xsession.windowManager.i3 = {
        enable = true;
        package = pkgs.i3;

        config = {
          modifier = "Mod4"; # Super key

          gaps = {
            inner = 4;
            outer = 4;
            smartGaps = true;
          };

          keybindings = let
            modifier = "Mod4";
          in

            lib.mkOptionDefault {
              # Terminal launcher
              "${modifier}+Return" = "exec console_launcher";
              "${modifier}+Shift+a" = "kill";

              "${modifier}+h" = "focus left";
              "${modifier}+j" = "focus down";
              "${modifier}+k" = "focus up";
              "${modifier}+l" = "focus right";

              # Move window
              "${modifier}+Shift+h" = "move left";
              "${modifier}+Shift+j" = "move down";
              "${modifier}+Shift+k" = "move up";
              "${modifier}+Shift+l" = "move right";

              # Azerty workspace bindings
              "${modifier}+ampersand" = "workspace number 1";
              "${modifier}+eacute" = "workspace number 2";
              "${modifier}+quotedbl" = "workspace number 3";
              "${modifier}+apostrophe" = "workspace number 4";
              "${modifier}+parenleft" = "workspace number 5";
              "${modifier}+minus" = "workspace number 6";
              "${modifier}+egrave" = "workspace number 7";
              "${modifier}+underscore" = "workspace number 8";
              "${modifier}+ccedilla" = "workspace number 9";
              "${modifier}+agrave" = "workspace number 10";

              # Move container to workspace (azerty)
              "${modifier}+Shift+ampersand" = "move container to workspace number 1";
              "${modifier}+Shift+eacute" = "move container to workspace number 2";
              "${modifier}+Shift+quotedbl" = "move container to workspace number 3";
              "${modifier}+Shift+apostrophe" = "move container to workspace number 4";
              "${modifier}+Shift+parenleft" = "move container to workspace number 5";
              "${modifier}+Shift+minus" = "move container to workspace number 6";
              "${modifier}+Shift+egrave" = "move container to workspace number 7";
              "${modifier}+Shift+underscore" = "move container to workspace number 8";
              "${modifier}+Shift+ccedilla" = "move container to workspace number 9";
              "${modifier}+Shift+agrave" = "move container to workspace number 10";

              # Nemo
              "${modifier}+n" = "exec nemo --no-desktop";

              # Launcher, lock, exit
              "${modifier}+d" = "exec dmenu_run";
              "${modifier}+Shift+x" = "exec i3lock -c 000000";
              "${modifier}+Shift+e" = "exec i3-msg exit";
            };

          startup = [
            {
              # Random wallpaper at each start, from the configs repo
              # consumed as a flake input (same source as the vim config):
              # the Nix interpolation points at the input's store path,
              # the glob stays literal and expands in i3's shell
              command = "feh --randomize --bg-fill ${inputs.niluje-configs}/wallpapers/*";
              always = false;
              notification = false;
            }
            {
              command = "systemctl --user start hm-graphical-session.target";
              always = false;
              notification = false;
            }
            {
              command = "${pkgs.polkit_gnome}/libexec/polkit-gnome-authentication-agent-1";
              always = false;
              notification = false;
            }
          ];

          bars = [
            {
              position = "top";
              fonts = {
                names = ["Noto Nerd Font"];
                size = 10.0;
              };
              statusCommand = "${pkgs.i3status-rust}/bin/i3status-rs ~/.config/i3status-rust/config-default.toml";
            }
          ];
        };
      };

      # i3status-rust: minimal modern bar
      programs.i3status-rust = {
        enable = true;
        bars = {
          default = {
            theme = "native";
            icons = "material-nf";
            blocks = [
              {
                block = "cpu";
              }
              {
                block = "memory";
              }
              {
                block = "net";
              }
              {
                block = "battery";
                missing_format = "";
              }
              {
                block = "time";
              }
            ];
          };
        };
      };
    };
  });
}
