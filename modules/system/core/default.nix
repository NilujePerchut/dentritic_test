{
  self,
  inputs,
  ...
}: {
  flake.nixosModules.core = {
    pkgs,
    lib,
    ...
  }: let
    modules = with self.nixosModules; [
      user
      bootloader
      nix
      locale
      hosts
      audio
    ];
  in {
    imports = modules;

    services = {
      openssh = {
        enable = true;
        settings = {
          PermitRootLogin = "yes";
        };
      };
    };

    environment.systemPackages = with pkgs; [
      git
      neovim
      curlWithGnuTls
      wget
      zsh
    ];

    # Setup neaovim as default editor
    programs.neovim.enable = true;
    programs.neovim.defaultEditor = true;
    programs.neovim.viAlias = true;
    programs.neovim.vimAlias = true;

    # Use ZSH per default
    environment.shells = with pkgs; [bash zsh ];
    users.defaultUserShell = pkgs.zsh;
    programs.zsh.enable = true;

    system.stateVersion = "26.02";
  };
}
