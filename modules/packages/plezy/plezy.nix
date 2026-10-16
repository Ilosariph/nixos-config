{ ... }: {
  flake.nixosModules.plezy = { config, lib, pkgs, ... }:
    lib.mkIf config.dotfiles.programs.plezy.enable {
      # Plex/Jellyfin/Emby client. Server login is done in-app — connections
      # and auth tokens live in its own DB, so no declarative server config.
      home-manager.users.${config.dotfiles.user.name} = { ... }: {
        home.packages = [ pkgs.plezy ];
      };
    };
}
