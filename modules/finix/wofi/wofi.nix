{ ... }: {
  flake.finixModules.wofi = { config, lib, pkgs, ... }:
    lib.mkIf config.dotfiles.desktop.enable {
      environment.systemPackages = [ pkgs.wofi ];
      hjem.users.${config.dotfiles.user.name}.xdg.config.files = {
        "wofi/config".source = ../../packages/wofi/config;
        "wofi/style.css".source = ../../packages/wofi/style.css;
      };
    };
}
