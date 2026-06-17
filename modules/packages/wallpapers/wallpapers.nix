{ ... }: {
  flake.nixosModules.wallpapers = { config, pkgs, lib, ... }:
    lib.mkIf config.dotfiles.desktop.enable {
      home-manager.users.${config.dotfiles.user.name} = { ... }:
        let
          wallpaperStore = pkgs.runCommand "wallpapers" { } ''
            mkdir -p $out
            cp -r ${config.dotfiles.wallpapers.directory}/. $out/
          '';
        in {
          home.sessionVariables.WALLPAPER_DIR = "${wallpaperStore}";
        };
    };
}
