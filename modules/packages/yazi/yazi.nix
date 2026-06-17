{ ... }: {
  flake.nixosModules.yazi = { config, lib, pkgs, ... }:
    lib.mkIf config.dotfiles.programs.yazi.enable {
      home-manager.users.${config.dotfiles.user.name} = { config, ... }: {
        programs.yazi.enable = true;
        programs.yazi.shellWrapperName = "yy";
        programs.yazi.plugins = {
          sshfs = pkgs.yaziPlugins.sshfs;
        };
        home.packages = [ pkgs.sshfs ];
        programs.yazi.keymap = {
          mgr.prepend_keymap = [
            {
              on = "M";
              run = "plugin sshfs -- menu";
              desc = "SSHFS menu";
            }
            {
              run = [
                ''shell -- for path in "$@"; do echo "file://$path"; done | wl-copy -t text/uri-list''
                "yank"
              ];
              on = "y";
            }
          ];
        };
        programs.yazi.settings = {
          preview = {
            cache_dir = "${config.xdg.cacheHome}/yazi/preview-cache";
            max_width = 1920;
          };
          tasks = {
            image_bound = [0 0];
          };
        };
      };
    };
}
