{ ... }: {
  flake.nixosModules.neovim = { config, lib, ... }: {
    home-manager.users.${config.dotfiles.user.name} = { lib, osConfig, ... }:
      lib.mkIf osConfig.dotfiles.programs.neovim.enable {
        programs.neovim = {
          enable = true;
          withRuby = false;
          withPython3 = false;
        };
        xdg.configFile."nvim" = {
          source = ./nvim;
          recursive = true;
        };
        xdg.configFile."nvim/scheme.lua".text = ''
          vim.cmd.colorscheme '${osConfig.dotfiles.theme.neovimScheme}'
        '';
      };
  };
}
