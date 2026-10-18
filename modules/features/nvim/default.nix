{
  self,
  moduleWithSystem,
  ...
}: {
  flake.nixosModules.nvim = moduleWithSystem ({pkgs, ...}:
  {
    environment.systemPackages = with pkgs; [
      # Base programs
      neovim
      # Dependencies
      git
      gcc
      nodejs
      unzip
      ripgrep
      yarn
      fd
    ];

    home-manager.users.niluje = {
      programs.neovim = {
        enable = true;
	extraLuaConfig = ''
          vim.opt.number = true
          vim.opt.relativenumber = true
        '';
      };
    };
  });
}
