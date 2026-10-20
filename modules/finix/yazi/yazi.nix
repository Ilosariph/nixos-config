{ ... }: {
  # yazi everywhere (TUI); `yy` is home-manager's cd-on-exit shell wrapper
  flake.finixModules.yazi = { config, lib, pkgs, ... }:
    let
      toml = pkgs.formats.toml { };
      home = "/home/${config.dotfiles.user.name}";
    in {
      environment.systemPackages = [ pkgs.yazi ];

      hjem.users.${config.dotfiles.user.name}.xdg.config.files = {
        "yazi/keymap.toml".source = toml.generate "keymap.toml" {
          mgr.prepend_keymap = [
            {
              run = [
                ''shell -- for path in "$@"; do echo "file://$path"; done | wl-copy -t text/uri-list''
                "yank"
              ];
              on = "y";
            }
            {
              run = "cd /mnt";
              on = [ "g" "m" ];
              desc = "Go to /mnt";
            }
          ];
        };
        "yazi/yazi.toml".source = toml.generate "yazi.toml" {
          mgr.linemode = "size";
          preview = {
            cache_dir = "${home}/.cache/yazi/preview-cache";
            max_width = 1920;
          };
          tasks.image_bound = [ 0 0 ];
          # One detached (orphan) window per selected file, see the NixOS aspect
          opener = {
            image = [
              { run = ''for f in %s; do setsid qview "$f" >/dev/null 2>&1 & done''; orphan = true; desc = "View images"; for = "unix"; }
            ];
            video = [
              { run = ''for f in %s; do setsid mpv "$f" >/dev/null 2>&1 & done''; orphan = true; desc = "Play videos"; for = "unix"; }
            ];
            open = [
              { run = ''for f in %s; do setsid xdg-open "$f" >/dev/null 2>&1 & done''; orphan = true; desc = "Open"; for = "unix"; }
            ];
          };
          open.prepend_rules = [
            { mime = "image/*"; use = "image"; }
            { mime = "video/*"; use = "video"; }
          ];
        };
        "fish/functions/yy.fish".text = ''
          function yy
            set -l tmp (mktemp -t "yazi-cwd.XXXXX")
            command yazi $argv --cwd-file="$tmp"
            if read -z cwd < "$tmp"; and [ -n "$cwd" ]; and [ "$cwd" != "$PWD" ]
              builtin cd -- "$cwd"
            end
            command rm -f -- "$tmp"
          end
        '';
      };
    };
}
