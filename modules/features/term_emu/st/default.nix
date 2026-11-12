{
  self,
  inputs,
  moduleWithSystem,
  ...
}: {
  flake.nixosModules.stTerm = moduleWithSystem ({pkgs, ...}: {config, lib, ...}: let
    cfg = config.services.termEmu.st;

    # Patches are applied in order: scrollback first (touches st.c
    # around regions the graphics patch also modifies), theme last
    # (config.def.h colors only). If a bump breaks an application,
    # reorder or regenerate the failing hunks.
    patches =
      lib.optionals cfg.scrollback [
        ./patches/st-scrollback-ringbuffer-0.9.2.diff
        ./patches/st-scrollback-mouse-0.9.2.diff
      ]
      ++ lib.optionals (cfg.theme == "onedark") [
        ./patches/st-onedark-0.9.3.diff
      ];

    stPatched = pkgs.st.overrideAttrs (old: {
      inherit patches;
      postPatch = (old.postPatch or "") + ''
        # Font (pixelsize: predictable on VMs where X DPI is unreliable)
        sed -i -E 's/^static char \*font *= *"[^"]*"/static char *font = "${cfg.font}:pixelsize=${toString cfg.fontSize}:antialias=true:autohint=true"/' config.def.h

        # Fail the build loudly if the font line was not substituted,
        # so a future patch bump cannot silently revert the font.
        grep -q 'font = "${cfg.font}:pixelsize=${toString cfg.fontSize}' config.def.h || { echo "ERROR: font substitution failed in config.def.h" >&2; exit 1; }

        # Zoom shortcuts from the legacy config.h: Ctrl+= / Ctrl+- and
        # Ctrl+Shift+Home (zoom reset), inserted at the end of shortcuts[]
        sed -i 's|{ TERMMOD,              XK_Num_Lock,    numlock,        {.i =  0} },|{ TERMMOD,              XK_Num_Lock,    numlock,        {.i =  0} },\n\t{ ControlMask,          XK_equal,       zoom,           {.f = +1} },\n\t{ ControlMask,          XK_minus,       zoom,           {.f = -1} },\n\t{ TERMMOD,              XK_Home,        zoomreset,       {.f =  0} },|' config.def.h
      '';
    });
  in {
    options.services.termEmu.st = {
      font = lib.mkOption {
        type = lib.types.str;
        default = "NotoMono Nerd Font Mono";
        description = "Fontconfig family name for st.";
      };

      fontSize = lib.mkOption {
        type = lib.types.int;
        default = 20;
        description = "Font pixel size.";
      };

      theme = lib.mkOption {
        type = lib.types.enum [ "default" "onedark" ];
        default = "onedark";
        description = "Color scheme applied via suckless patch.";
      };

      scrollback = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = "Scrollback ringbuffer + mouse scrolling patches.";
      };

      kittyGraphics = lib.mkOption {
        type = lib.types.bool;
        default = false;
        description = "Kitty graphics protocol (image previews, imlib2).";
      };
    };

    config = {
      fonts.packages = [ pkgs.nerd-fonts.noto ];
      environment.systemPackages = [ stPatched ];
    };
  });
}
