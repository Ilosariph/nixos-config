{ ... }: {
  flake.nixosModules.yazi = { config, lib, ... }:
    lib.mkIf config.dotfiles.programs.yazi.enable {
      home-manager.users.${config.dotfiles.user.name} = { config, osConfig, ... }:
        let
          editor = osConfig.dotfiles.programs.defaultEditor;
          isTui = editor == "helix" || editor == "neovim";
          editorRun = { helix = ''hx "$@"''; neovim = ''nvim "$@"''; zed = ''zed "$@"''; }.${editor};
          editorDesc = { helix = "Helix"; neovim = "Neovim"; zed = "Zed"; }.${editor};
        in
        {
          programs.yazi.enable = true;
          programs.yazi.shellWrapperName = "yy";
          programs.yazi.settings = {
            preview = {
              cache_dir = "${config.xdg.cacheHome}/yazi/preview-cache";
              max_width = 1920;
            };
            tasks = {
              image_bound = [ 0 0 ];
            };
            opener.edit = [{ run = editorRun; desc = editorDesc; block = isTui; }];
            open.prepend_rules = [
              { mime = "text/*"; use = "edit"; }
              { mime = "application/json"; use = "edit"; }
              { mime = "application/toml"; use = "edit"; }
              { mime = "application/xml"; use = "edit"; }
              { mime = "text/xml"; use = "edit"; }
              { mime = "application/x-yaml"; use = "edit"; }
            ];
          };
          programs.yazi.keymap = {
            mgr.prepend_keymap = [
              {
                run = [
                  ''shell -- for path in "$@"; do echo "file://$path"; done | wl-copy -t text/uri-list''
                  "yank"
                ];
                on = "y";
              }
            ];
          };
        };
    };
}
