{ ... }: {
  flake.nixosModules.neovim = { config, lib, ... }: {
    home-manager.users.${config.dotfiles.user.name} = { lib, osConfig, ... }:
      lib.mkIf osConfig.dotfiles.programs.neovim.enable {
        programs.neovim.enable = true;
        xdg.configFile."nvim" = {
          source = ./nvim;
        };
      };
  };
}
