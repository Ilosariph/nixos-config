{ config, pkgs, lib, osConfig, ... }:
let
  cfg = osConfig.dotfiles.hyprland.settings;
in {
  programs.kitty.enable = true;
  wayland.windowManager.hyprland.enable = true;


  wayland.windowManager.hyprland.settings = lib.mkMerge [
    (let
      hyprland-settings = {
        exec-once = [
          "hyprpaper"
          "hypridle"
          "gsettings set org.gnome.desktop.interface cursor-theme '${config.home.pointerCursor.name}'"
          "gsettings set org.gnome.desktop.interface cursor-size ${toString config.home.pointerCursor.size}"
          "pulsemeeter"
          "qpwgraph"
          "systemctl --user import-environment WAYLAND_DISPLAY DISPLAY PATH XDG_DATA_DIRS XDG_CURRENT_DESKTOP"
          "systemctl --user stop xdg-desktop-portal xdg-desktop-portal-gtk xdg-desktop-portal-hyprland"
          "systemctl --user start xdg-desktop-portal xdg-desktop-portal-hyprland"
          "clipse -listen"
          "wl-clip-persist --clipboard regular"
          "nm-applet --indicator"
          "1password --silent"
        ] ++ cfg.execOnce;

        exec = [
          "pkill -SIGUSR2 waybar || waybar"
        ];

        env = [
          "XDG_CURRENT_DESKTOP,Hyprland"
          "XDG_SESSION_TYPE,wayland"
          "XDG_SESSION_DESKTOP,Hyprland"
        ];

        general = {
          "gaps_in" = 5;
          "gaps_out" = 10;
          "border_size" = 2;
          "col.active_border" = "rgba(33ccffee) rgba(00ff99ee) 45deg";
          "col.inactive_border" = "rgba(595959aa)";
          "resize_on_border" = false;
          "allow_tearing" = false;
          "layout" = "dwindle";
        };

        windowrulev2 = [
          "suppressevent maximize, class:.*"

          "opacity 1.0 override 1.0 override, class:^(com.interversehq.qView)$"
          "opacity 1.0 override 1.0 override, class:^(mpv)$"
          "opacity 0.97 0.9, class:.*"
          "opacity 1 1, class:^(cef)$, title:^(Grayjay)$"

          "noborder, class:^(kitty)$"
          "workspace special:pulsemeeter silent, class:^(org.pulsemeeter.pulsemeeter)$"
          "float, class:^(org.pulseaudio.pavucontrol|blueberry.py)$"

          "nofocus,class:^$,title:^$,xwayland:1,floating:1,fullscreen:0,pinned:0"

          "float, class:(clipse)"
          "size 622 652, class:(clipse)"
          "stayfocused, class:(clipse)"
        ];

        layerrule = [
          "blur,waybar"
        ];

        decoration = {
          "rounding" = 4;
          "active_opacity" = 1.0;
          "inactive_opacity" = 0.97;
          shadow = {
            "enabled" = false;
            "range" = 30;
            "render_power" = 3;
            "ignore_window" = true;
            "color" = "rgba(00000045)";
          };
          blur = {
            "enabled" = true;
            "size" = 5;
            "passes" = 2;
            "vibrancy" = 0.1696;
          };
        };

        animations = {
          enabled = true;

          bezier = [
            "easeOutQuint, 0.23, 1, 0.32, 1"
            "easeInOutCubic, 0.65, 0.05, 0.36, 1"
            "linear, 0, 0, 1, 1"
            "almostLinear, 0.5, 0.5, 0.75, 1.0"
            "quick, 0.15, 0, 0.1, 1"
          ];

          animation = [
            "global, 1, 10, default"
            "border, 1, 5.39, easeOutQuint"
            "windows, 1, 4.79, easeOutQuint"
            "windowsIn, 1, 4.1, easeOutQuint, popin 87%"
            "windowsOut, 1, 1.49, linear, popin 87%"
            "fadeIn, 1, 1.73, almostLinear"
            "fadeOut, 1, 1.46, almostLinear"
            "fade, 1, 3.03, quick"
            "layers, 1, 3.81, easeOutQuint"
            "layersIn, 1, 4, easeOutQuint, fade"
            "layersOut, 1, 1.5, linear, fade"
            "fadeLayersIn, 1, 1.79, almostLinear"
            "fadeLayersOut, 1, 1.39, almostLinear"
            # Workspace animations disabled for snappy feel
            "workspaces, 0, 0, ease"
          ];
        };

        dwindle = {
          "pseudotile" = true;
          "preserve_split" = true;
          "force_split" = 2;
        };

        master.new_status = "master";

        misc = {
          force_default_wallpaper = -1;
          disable_hyprland_logo = true;
          disable_splash_rendering = true;
        };

        input = {
          kb_layout = "ch";
          kb_options = "caps:escape";

          follow_mouse = 1;

          touchpad = {
            natural_scroll = true;
          };
        };

        cursor = {
          inactive_timeout = 3;
        };

        # Program variables
        "$mainMod" = "SUPER";
        "$terminal" = "kitty";
        "$fileManager" = "kitty yazi";
        "$menu" = "wofi --show drun --sort-order=alphabetical";
        "$screenshotUtil" = "grimblast -f save area - | swappy -f -";
        "$lock" = "hyprlock";

        bind = [
          # ── My core bindings ───────────────────────────────────────────
          "$mainMod, Q, exec, $terminal"
          "$mainMod, C, killactive"
          "$mainMod, E, exec, $fileManager"
          "$mainMod, V, togglefloating"
          "$mainMod, SPACE, exec, $menu"
          "$mainMod, T, togglesplit"
          "$mainMod ALT, L, exec, $lock"

          # ── Additional kill / session management ───────────────────────
          "$mainMod, W, killactive"
          "$mainMod, Backspace, killactive"
          "$mainMod, ESCAPE, exec, $lock"
          "$mainMod SHIFT, ESCAPE, exit,"
          "$mainMod CTRL, ESCAPE, exec, reboot"
          "$mainMod SHIFT CTRL, ESCAPE, exec, systemctl poweroff"

          # ── Tiling helpers ─────────────────────────────────────────────
          "$mainMod, P, pseudo"
          "$mainMod SHIFT, Plus, fullscreen,"

          # ── Waybar toggle ──────────────────────────────────────────────
          "$mainMod SHIFT, SPACE, exec, pkill -SIGUSR1 waybar"

          # ── Screenshots ────────────────────────────────────────────────
          ", Print, exec, $screenshotUtil"
          "SHIFT, Print, exec, grimblast -f save screen - | swappy -f -"
          "CTRL, Print, exec, grimblast -f save active - | swappy -f -"
          "$mainMod, Print, exec, hyprpicker -a"

          # ── Clipboard manager (clipse) ─────────────────────────────────
          "SHIFT $mainMod, V, exec, kitty --class clipse -e clipse"

          # ── Special workspace ──────────────────────────────────────────
          "$mainMod, S, togglespecialworkspace, magic"
          "$mainMod SHIFT, S, movetoworkspace, special:magic"
          "$mainMod, F1, togglespecialworkspace, pulsemeeter"

          # ── Focus movement (machine-specific $left/$right/$up/$down) ───
          "$mainMod, $left, movefocus, l"
          "$mainMod, $right, movefocus, r"
          "$mainMod, $up, movefocus, u"
          "$mainMod, $down, movefocus, d"

          # ── Swap windows ────────────────────────────────────────────────
          "$mainMod SHIFT, left, swapwindow, l"
          "$mainMod SHIFT, right, swapwindow, r"
          "$mainMod SHIFT, up, swapwindow, u"
          "$mainMod SHIFT, down, swapwindow, d"

          # ── Move windows (my custom keys) ──────────────────────────────
          "$mainMod SHIFT, N, movewindow, l"
          "$mainMod SHIFT, I, movewindow, r"
          "$mainMod SHIFT, U, movewindow, u"
          "$mainMod SHIFT, comma, movewindow, d"

          # ── Workspace shortcuts ────────────────────────────────────────
          "$mainMod, mouse_down, workspace, e+1"
          "$mainMod, mouse_up, workspace, e-1"
        ]
        ++ (
          # workspaces – binds $mod + [shift +] {1..9} to [move to] workspace {1..9}
          builtins.concatLists (
            builtins.genList (i:
              let ws = i + 1;
              in [
                "$mainMod, code:1${toString i}, workspace, ${toString ws}"
                "$mainMod SHIFT, code:1${toString i}, movetoworkspace, ${toString ws}"
              ]
            )
          9)
        );

        # ── Mouse binds ──────────────────────────────────────────────────
        bindm = [
          "$mainMod, mouse:272, movewindow"
          "$mainMod, mouse:273, resizewindow"
        ];

        # ── Repeating binds when held ────────────────────────────────────
        binde = [
          "$mainMod CTRL, $left, resizeactive, -50 0"
          "$mainMod CTRL, $right, resizeactive, 50 0"
          "$mainMod CTRL, $up, resizeactive, 0 -50"
          "$mainMod CTRL, $down, resizeactive, 0 50"
          "$mainMod ALT, $left, moveactive, -50 0"
          "$mainMod ALT, $right, moveactive, 50 0"
          "$mainMod ALT, $up, moveactive, 0 -50"
          "$mainMod ALT, $down, moveactive, 0 50"
        ];

        # ── Multimedia / laptop keys ─────────────────────────────────────
        bindel = [
          ",XF86AudioRaiseVolume, exec, wpctl set-volume -l 1 @DEFAULT_AUDIO_SINK@ 5%+"
          ",XF86AudioLowerVolume, exec, wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%-"
          ",XF86AudioMute, exec, wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle"
          ",XF86AudioMicMute, exec, wpctl set-mute @DEFAULT_AUDIO_SOURCE@ toggle"
          ",XF86MonBrightnessUp, exec, brightnessctl -e4 -n2 set 5%+"
          ",XF86MonBrightnessDown, exec, brightnessctl -e4 -n2 set 5%-"
        ];

        bindl = [
          ", XF86AudioNext, exec, playerctl next"
          ", XF86AudioPause, exec, playerctl play-pause"
          ", XF86AudioPlay, exec, playerctl play-pause"
          ", XF86AudioPrev, exec, playerctl previous"
        ];
      };
    in hyprland-settings)
    {
      monitor = lib.mkIf (cfg.monitors != []) cfg.monitors;
      workspace = lib.mkIf (cfg.workspaces != []) cfg.workspaces;
      input = {
        sensitivity = lib.mkIf (cfg.sensitivity != null) cfg.sensitivity;
        accel_profile = lib.mkIf (cfg.accel_profile != null) cfg.accel_profile;
      };
      "$left" = cfg.left;
      "$right" = cfg.right;
      "$up" = cfg.up;
      "$down" = cfg.down;
    }
  ];
}
