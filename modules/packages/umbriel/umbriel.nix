{ ... }: {
  # Umbriel: Noctalia's wlroots compositor (scrolling/dwindle/master layouts).
  # Alternative to niri, selected with dotfiles.windowManager.type = "umbriel".
  # Config mirrors niri.nix as closely as Umbriel's actions allow.
  # Docs: https://docs.noctalia.dev/umbriel/
  flake.nixosModules.umbriel = { config, pkgs, lib, ... }:
    let
      isDesktop = config.dotfiles.desktop.enable;
      isUmbrielPrimary = isDesktop && config.dotfiles.windowManager.type == "umbriel";
    in {
      # Installs umbriel, registers the wayland session for greetd/tuigreet,
      # and adds xdg-desktop-portal-umbriel (screencast)
      programs.umbriel.enable = lib.mkIf isUmbrielPrimary true;

      # Umbriel starts Xwayland itself on demand (general.xwayland), it only
      # needs the binary on PATH
      programs.xwayland.enable = lib.mkIf isUmbrielPrimary true;

      xdg.portal = lib.mkIf isUmbrielPrimary {
        enable = true;
        extraPortals = [ pkgs.xdg-desktop-portal-gtk ];
        config.umbriel.default = [ "umbriel" "gtk" ];
      };

      security.polkit.enable = lib.mkIf isUmbrielPrimary true;
      services.gnome.gnome-keyring.enable = lib.mkIf isUmbrielPrimary true;
      security.pam.services.swaylock = lib.mkIf isUmbrielPrimary {};
      security.pam.services.login = lib.mkIf isUmbrielPrimary { enableGnomeKeyring = true; };

      environment.systemPackages = lib.optionals isUmbrielPrimary (with pkgs; [
        swaylock
        swayidle
      ]);

      # Home-manager config
      home-manager.users.${config.dotfiles.user.name} = { lib, pkgs, osConfig, ... }:
        let
          cfg = osConfig.dotfiles.windowManager.settings;
          statusbar = osConfig.dotfiles.windowManager.statusbar;
          tomlFormat = pkgs.formats.toml { };

          parseMonitorConfig = monitorStr:
            let
              parts = lib.splitString ", " monitorStr;
              name = lib.elemAt parts 0;
              mode = lib.elemAt parts 1;
              position = lib.elemAt parts 2;
              scale = lib.elemAt parts 3;
              posParts = lib.splitString "x" position;
              posX = lib.toInt (lib.elemAt posParts 0);
              posY = lib.toInt (lib.elemAt posParts 1);
            in {
              inherit name mode;
              position = [ posX posY ];
              scale = builtins.fromJSON scale;
            };

          monitors = map parseMonitorConfig cfg.monitors;

          # Umbriel matches keysyms case-insensitively; keep niri's spelling
          keyName = key:
            if key == "comma" then "Comma"
            else lib.toUpper (lib.substring 0 1 key) + lib.substring 1 (-1) key;

          leftKey = keyName cfg.left;
          rightKey = keyName cfg.right;
          upKey = keyName cfg.up;
          downKey = keyName cfg.down;

          # Bind both the configured direction keys and the arrow keys
          dirBinds = prefix: actions:
            lib.listToAttrs (lib.concatLists (lib.mapAttrsToList (dir: action:
              let
                keys = {
                  left = [ leftKey "Left" ];
                  right = [ rightKey "Right" ];
                  up = [ upKey "Up" ];
                  down = [ downKey "Down" ];
                }.${dir};
              in map (k: lib.nameValuePair "${prefix}${k}" action) keys
            ) actions));

          once = action: { inherit action; repeat = false; };
          locked = action: { inherit action; allow_when_locked = true; };

          lockAction =
            if statusbar == "noctalia"
            then "spawn:noctalia msg session lock"
            else "spawn:swaylock";

          launcherAction =
            if statusbar == "noctalia"
            then "spawn:noctalia msg panel-toggle launcher"
            else "spawn:wofi --show drun --sort-order=alphabetical";

          baseAutostart =
            # noctalia daemon is started by its systemd user service (programs.noctalia.systemd.enable)
            lib.optionals (statusbar == "waybar") [ "waybar" ]
            ++ lib.optionals osConfig.dotfiles.programs._1password.enable [ "1password --silent" ];

          autostart = baseAutostart ++ cfg.execOnce;

          workspaceBinds = lib.listToAttrs (lib.concatLists (builtins.genList (i:
            let ws = toString (i + 1); in [
              (lib.nameValuePair "Mod+${ws}" "workspace-switch:${ws}")
              (lib.nameValuePair "Mod+Shift+${ws}" "column-move-to-workspace:${ws}")
            ]) 9));

          regionShot = "screenshot-region";

          settings = {
            general = {
              inherit autostart;
            };

            environment = {
              NIXOS_OZONE_WL = "1";
            };

            input = {
              keyboard = {
                layout = osConfig.dotfiles.locale.xkbLayout;
                options = "caps:escape";
                numlock_toggle = true;
              };
              touchpad = {
                tap = true;
                natural_scroll = true;
              };
              # Same as niri's focus-follows-mouse max-scroll-amount="0%"
              focus = {
                follows_mouse = true;
                follows_mouse_max_scroll = 0.0;
              };
            } // lib.optionalAttrs osConfig.dotfiles.programs.yeetmouse.enable {
              mouse = {
                accel_profile = "flat";
                sensitivity = 0.0;
              };
            };

            output = lib.listToAttrs (map (mon: lib.nameValuePair mon.name {
              inherit (mon) mode position scale;
            }) monitors);

            layout = {
              gap = 16;
              extent_presets = [ 0.33333 0.5 0.66667 ];
              scrolling = {
                default_extent_fraction = 0.5;
                center_focused = "never";
              };
            };

            appearance = {
              prefer_no_csd = true;
              border_width = 2;
              corner_radius = 8;
            };

            colors.border = {
              focused = "#7FC8FFFF";
              unfocused = "#505050FF";
            };

            # "tools" scratchpad, like Hyprland's special:tools workspace:
            # StreamController opens hidden in it, Mod+F1 shows it on the
            # focused output
            scratchpad = [ { name = "tools"; } ];

            window_rule = [
              # Steam games open fullscreen
              {
                match.app_id = "^steam_app_\\d+$";
                default_fullscreen = true;
              }
              # Any window takes the full width on an empty workspace,
              # otherwise the default 50%
              {
                match.is_alone = true;
                default_scrolling_extent = 1.0;
              }
              # Plezy always takes the full width
              {
                match.app_id = "^com\\.edde746\\.plezy$";
                default_scrolling_extent = 1.0;
              }
              {
                match.app_id = "^com\\.core447\\.StreamController$";
                default_scratchpad = "tools";
                default_floating_size = { width = 0.8; height = 0.8; };
              }
            ];

            # Defining [keybinds] replaces Umbriel's built-in set
            keybinds = {
              "Mod+Shift+Slash" = "cheatsheet-toggle";

              # Core bindings
              "Mod+Q" = once "spawn:kitty";
              "Mod+E" = once "spawn:kitty -e yazi";
              "Mod+Space" = once launcherAction;
              "Mod+Escape" = once lockAction;

              "Mod+C" = once "window-close";
              "Mod+V" = once "window-toggle-floating";
              "Mod+O" = once "overview-toggle";
            } // lib.optionalAttrs (osConfig.dotfiles.audio.routing == "pipewire-virtual") {
              "Mod+Shift+O" = once "spawn:audio-output";
              "Mod+Shift+M" = once "spawn:audio-input";
              "Mod+Shift+D" = once "spawn:audio-device";
              "Mod+Shift+A" = once "spawn:mic-mute";
            }
            # Umbriel-style consume/expel. Merged before the direction binds so
            # those win where they collide (Colemak uses Comma for down).
            // {
              "Mod+Comma" = "window-consume-left";
              "Mod+Period" = "window-consume-right";
              "Mod+Shift+Comma" = "window-consume-or-expel-left";
              "Mod+Shift+Period" = "window-consume-or-expel-right";
            }
            # Focus / move windows
            // dirBinds "Mod+" {
              left = "window-focus-left";
              right = "window-focus-right";
              up = "window-focus-up";
              down = "window-focus-down";
            }
            // dirBinds "Mod+Shift+" {
              left = "column-move-left";
              right = "column-move-right";
              up = "window-move-up";
              down = "window-move-down";
            }
            # Focus / move to monitors
            // dirBinds "Mod+Ctrl+" {
              left = "output-focus-left";
              right = "output-focus-right";
              up = "output-focus-up";
              down = "output-focus-down";
            }
            // dirBinds "Mod+Shift+Ctrl+" {
              left = "column-move-to-output-left";
              right = "column-move-to-output-right";
              up = "column-move-to-output-up";
              down = "column-move-to-output-down";
            }
            # Workspaces
            // workspaceBinds
            // {
              "Mod+F1" = "scratchpad-toggle:tools";
              "Mod+Shift+F1" = once "window-toggle-scratchpad:tools";

              # Window management
              "Mod+R" = "window-cycle-primary-extent";
              "Mod+Shift+R" = "window-cycle-secondary-extent";
              "Mod+F" = once "window-toggle-maximize";
              "Mod+Shift+F" = once "window-toggle-fullscreen";
              # niri's consume-window-into-column; window-consume-from-right
              # is closer but not yet in the nixpkgs umbriel snapshot
              "Mod+T" = "window-consume-left";
              "Mod+Shift+T" = "window-consume-or-expel-right";

              # Screenshots
              "Print" = once "spawn:${regionShot}";
              "Shift+Print" = once ''spawn:sh -c "grim - | swappy -f -"'';
              "Ctrl+Print" = once "spawn:screenshot-region -o";
              # Same as Print, for keyboards without a Print key (e.g. macbook)
              "Mod+Shift+S" = once "spawn:${regionShot}";

              # Session (not Mod+Escape: Mod is Super, that chord is the lock)
              "Mod+Shift+Escape" = {
                action = "shortcuts-inhibit-toggle";
                allow_when_inhibited = true;
                repeat = false;
              };
              "Mod+Shift+E" = once "session-quit";
              "Ctrl+Alt+Delete" = once "session-quit";

              # Mouse wheel scrolling
              "Mod+WheelDown" = { action = "workspace-next"; cooldown_ms = 150; };
              "Mod+WheelUp" = { action = "workspace-previous"; cooldown_ms = 150; };

              # Multimedia / laptop keys (work while the screen is locked)
              "XF86AudioRaiseVolume" = locked "spawn:wpctl set-volume -l 1 @DEFAULT_AUDIO_SINK@ 5%+";
              "XF86AudioLowerVolume" = locked "spawn:wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%-";
              "XF86AudioMute" = locked "spawn:wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle";
              "XF86AudioMicMute" = locked "spawn:mic-mute";
              "XF86MonBrightnessUp" = locked "spawn:brightnessctl -e4 -n2 set 5%+";
              "XF86MonBrightnessDown" = locked "spawn:brightnessctl -e4 -n2 set 5%-";
              "XF86AudioNext" = locked "spawn:playerctl next";
              "XF86AudioPause" = locked "spawn:playerctl play-pause";
              "XF86AudioPlay" = locked "spawn:playerctl play-pause";
              "XF86AudioPrev" = locked "spawn:playerctl previous";
            };
          };
        in lib.mkIf isUmbrielPrimary {
          home.packages = with pkgs; [ grim slurp ];

          home.sessionVariables = {
            QT_QPA_PLATFORM = "wayland";
            QT_WAYLAND_DISABLE_WINDOWDECORATION = "1";
            GDK_BACKEND = "wayland";
            GSK_RENDERER = "ngl";
          };

          # Umbriel owns DISPLAY / XDG_CURRENT_DESKTOP / XDG_SESSION_TYPE itself
          systemd.user.sessionVariables = {
            GDK_BACKEND = "wayland";
            GSK_RENDERER = "ngl";
            NIXOS_OZONE_WL = "1";
          };

          xdg.configFile."umbriel/config.toml".source =
            tomlFormat.generate "umbriel-config.toml" settings;
        };
    };
}
