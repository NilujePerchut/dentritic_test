{
  self,
  inputs,
  moduleWithSystem,
  ...
}: {
  flake.nixosModules.zsh = moduleWithSystem ({pkgs, ...}: {config, ...}: let
    user = config.myConfig.user.name;
  in {
    environment.systemPackages = with pkgs; [
      # Base programs
      zsh
      starship
    ];

    home-manager.users.${user} = {
      # ZSH
      programs.zsh = {
        enable = true;
        enableCompletion = true;
        autosuggestion.enable = true;
        initContent = ''
          source ${inputs.niluje-configs}/zsh/.zshrc
        '';
      };

      # Startship
      programs.starship.enable = true;
      home.file.".config/starship.toml".source = "${inputs.niluje-configs}/zsh/starship.toml";
      home.sessionVariables.USING_NIXOS = "yes";
    };
  });
}
