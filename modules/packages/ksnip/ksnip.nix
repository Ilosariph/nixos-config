{ ... }: {
  flake.nixosModules.ksnip = { config, lib, pkgs, ... }:
    lib.mkIf (config.dotfiles.desktop.enable
      && config.dotfiles.programs.screenshot.tool == "ksnip") {
      home-manager.users.${config.dotfiles.user.name} = { ... }: {
        home.packages = [ pkgs.ksnip ];
      };
    };
}
