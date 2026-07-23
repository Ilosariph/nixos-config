{ ... }: {
  flake.nixosModules.yazi = { config, ... }:
    {
      home-manager.users.${config.dotfiles.user.name} = { config, ... }: {
        programs.yazi.enable = true;
        programs.yazi.shellWrapperName = "yy";
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
        programs.yazi.settings = {
          preview = {
            cache_dir = "${config.xdg.cacheHome}/yazi/preview-cache";
            max_width = 1920;
          };
          tasks = {
            image_bound = [0 0];
          };
          # Open each selected file in its own detached (orphan) window.
          # The default opener spawns one non-orphan xdg-open per file, which
          # fills yazi's opener task slots after a handful of files and then
          # stops opening anything. Orphaning each spawn avoids that.
          opener = {
            image = [
              { run = ''for f in "$@"; do setsid qview "$f" >/dev/null 2>&1 & done''; orphan = true; desc = "View images"; for = "unix"; }
            ];
            video = [
              { run = ''for f in "$@"; do setsid mpv "$f" >/dev/null 2>&1 & done''; orphan = true; desc = "Play videos"; for = "unix"; }
            ];
            open = [
              { run = ''for f in "$@"; do setsid xdg-open "$f" >/dev/null 2>&1 & done''; orphan = true; desc = "Open"; for = "unix"; }
            ];
          };
          open = {
            prepend_rules = [
              { mime = "image/*"; use = "image"; }
              { mime = "video/*"; use = "video"; }
            ];
          };
        };
      };
    };
}
