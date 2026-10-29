{
  self,
  moduleWithSystem,
  ...
}: {
  flake.nixosModules.samba =
    moduleWithSystem
    ({pkgs, ...}: {config, lib, ...}: let
      cfg = config.services.smb;

      shareOpts = {name, ...}: {
        options = {
          path = lib.mkOption {
            type = lib.types.str;
            description = "Share path (created in place if autoCreate)";
          };

          comment = lib.mkOption {
            type = lib.types.str;
            default = "";
            description = "Share description";
          };

          browseable = lib.mkOption {
            type = lib.types.bool;
            default = true;
            description = "Is the share visible in the share list";
          };

          readOnly = lib.mkOption {
            type = lib.types.bool;
            default = false;
            description = "Read only";
          };

          guestOk = lib.mkOption {
            type = lib.types.bool;
            default = false;
            description = "Guest allowed (invite)";
          };

          validUsers = lib.mkOption {
            type = lib.types.listOf lib.types.str;
            default = [];
            description = "Authorized users";
          };

          writeList = lib.mkOption {
            type = lib.types.listOf lib.types.str;
            default = [];
            description = "Users allowed to write on read-only shares";
          };

          forceUser = lib.mkOption {
            type = lib.types.nullOr lib.types.str;
            default = null;
            description = "Force UNIX user";
          };

          createMask = lib.mkOption {
            type = lib.types.str;
            default = "0664";
            description = "New file mask";
          };

          directoryMask = lib.mkOption {
            type = lib.types.str;
            default = "0775";
            description = "New directory mask";
          };

          autoCreate = lib.mkOption {
            type = lib.types.bool;
            default = true;
            description = "auto-create via tmpfiles with owner/group/mode";
          };

          owner = lib.mkOption {
            type = lib.types.str;
            default = "root";
            description = "UNIX owner if autoCreate";
          };

          group = lib.mkOption {
            type = lib.types.str;
            default = "users";
            description = "UNIX group if autoCreate";
          };

          mode = lib.mkOption {
            type = lib.types.str;
            default = "2775";
            description = "Rights if autoCreate (setgid recommended on pool)";
          };

          extraSettings = lib.mkOption {
            type = lib.types.attrsOf lib.types.anything;
            default = {};
            description = "Additional smb.conf settings";
          };
        };
      };

      userOpts = {name, ...}: {
        options = {
          passwordFile = lib.mkOption {
            type = lib.types.path;
            description = "File containing the Samba password (e.g. a sops secret path)";
          };
        };
      };

      shareSection = share: (
        {
          "path" = share.path;
          "comment" = share.comment;
          "browseable" = lib.mkIf (share.browseable) "yes"; # hmm : voir note 1
        }
      );

      mkSection = share: {
        "path" = share.path;
        "comment" = share.comment;
        "browseable" = if share.browseable then "yes" else "no";
        "read only" = if share.readOnly then "yes" else "no";
        "guest ok" = if share.guestOk then "yes" else "no";
        "create mask" = share.createMask;
        "directory mask" = share.directoryMask;
      }
      // lib.optionalAttrs (share.validUsers != []) {
        "valid users" = lib.concatStringsSep " " share.validUsers;
      }
      // lib.optionalAttrs (share.writeList != []) {
        "write list" = lib.concatStringsSep " " share.writeList;
      }
      // lib.optionalAttrs (share.forceUser != null) {
        "force user" = share.forceUser;
      }
      // share.extraSettings;
    in {
      options.services.smb = {
        enable = lib.mkEnableOption "Samba server";

        workgroup = lib.mkOption {
          type = lib.types.str;
          default = "WORKGROUP";
          description = "Windows workgroup";
        };

        serverString = lib.mkOption {
          type = lib.types.str;
          default = "Samba";
          description = "Server description";
        };

        discover = lib.mkOption {
          type = lib.types.bool;
          default = true;
          description = "Network discover (wsdd on Windows, avahi on macOS/Linux)";
        };

        extraGlobal = lib.mkOption {
          type = lib.types.attrsOf lib.types.anything;
          default = {};
          description = "Additional global options";
        };

        shares = lib.mkOption {
          type = lib.types.attrsOf (lib.types.submodule shareOpts);
          default = {};
          example = {
            media = {path = "/mnt/pool/media";};
            backups = {path = "/mnt/pool/backups"; readOnly = true;};
          };
          description = "SMB shares, each key = share name";
        };

        # Convention: one sops file per user, secrets/samba-<user>.sops.yaml,
        # containing a single "password" key.
        users = lib.mkOption {
          type = lib.types.attrsOf (lib.types.submodule userOpts);
          default = {};
          description = "SMB users, each key = username";
        };
      };

      config = lib.mkIf cfg.enable {
        services.samba = {
          enable = true;
          package = pkgs.samba4Full;
          openFirewall = true;
          settings =
            {
              "global" = {
                "workgroup" = cfg.workgroup;
                "server string" = cfg.serverString;
                "security" = "user";
                "server min protocol" = "SMB2_10";
              }
              // cfg.extraGlobal;
            }
            // lib.mapAttrs (_: mkSection) cfg.shares;
        };

        sops.secrets = lib.mapAttrs' (name: _:
          lib.nameValuePair "samba-${name}" {
            sopsFile = ../../../secrets/samba-${name}.sops.yaml;
            key = "password";
            # Re-apply the password whenever the secret changes
            restartUnits = ["samba-passwords.service"];
          }
        ) cfg.users;

        services.samba-wsdd = lib.mkIf cfg.discover {
          enable = true;
          discovery = true;
        };

        services.avahi = lib.mkIf cfg.discover {
          enable = true;
          publish.enable = true;
        };

        systemd.tmpfiles.rules = lib.flatten (
          lib.mapAttrsToList
          (_: share:
            lib.optional share.autoCreate
              "d ${share.path} ${share.mode} ${share.owner} ${share.group} -")
          cfg.shares
        );

        systemd.services.samba-passwords = lib.mkIf (cfg.users != {}) {
          description = "Set Samba user passwords from secret files";
          wantedBy = ["multi-user.target"];
          after = ["sops-nix.service" "samba-setup.service"];
          requires = ["sops-nix.service"];
          serviceConfig = {
            Type = "oneshot";
            RemainAfterExit = true;
            # Never leak the password in logs or temp files
            UMask = "0077";
          };
          script = ''
            set -euo pipefail
          '' + lib.concatStringsSep "\n" (lib.mapAttrsToList
            (name: user: let
              smbpasswd = "${pkgs.samba4Full}/bin/smbpasswd";
            in ''
              pw="$(cat ${user.passwordFile})"
              printf '%s\n%s\n' "$pw" "$pw" | ${smbpasswd} -s -a ${lib.escapeShellArg name}
            '')
            cfg.users);
        };
      };
    });
}
