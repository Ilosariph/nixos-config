{ ... }: {
  flake.finixModules.neovim = { config, lib, pkgs, ... }:
    lib.mkIf config.dotfiles.programs.neovim.enable {
      environment.systemPackages = [ pkgs.neovim ];
      hjem.users.${config.dotfiles.user.name}.xdg.config.files."nvim".source = ../../packages/neovim/nvim;
    };
}
