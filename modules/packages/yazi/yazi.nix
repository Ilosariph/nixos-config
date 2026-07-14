{ ... }: {
  flake.nixosModules.yazi = { config, ... }:
    {
      home-manager.users.${config.dotfiles.user.name} = { config, pkgs, ... }: {
        programs.yazi.enable = true;
        programs.yazi.shellWrapperName = "yy";

        # SSHFS integration: mount/browse remote hosts over SSH from within
        # yazi. The packaged plugin pins a commit that no longer needs a
        # `require("sshfs"):setup()` call in init.lua.
        programs.yazi.plugins.sshfs = pkgs.yaziPlugins.sshfs;
        # Runtime dependency for the plugin (the `sshfs` CLI). fusermount is
        # provided by the NixOS FUSE setuid wrapper.
        home.packages = [ pkgs.sshfs ];

        programs.yazi.keymap = {
          mgr.prepend_keymap = [
            {
              run = [
                ''shell -- for path in "$@"; do echo "file://$path"; done | wl-copy -t text/uri-list''
                "yank"
              ];
              on = "y";
            }
            {
              on = "M";
              run = "plugin sshfs -- menu";
              desc = "Open SSHFS menu";
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
