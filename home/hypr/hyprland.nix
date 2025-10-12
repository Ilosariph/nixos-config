{
  programs.kitty.enable = true;
  wayland.windowManager.hyprland.enable = true;

  # Optional, hint Electron apps to use Wayland:
  # home.sessionVariables.NIXOS_OZONE_WL = "1";
  home.sessionVariables = {
    XCURSOR_SIZE = 24;
    HYPRCURSOR_SIZE = 24;
  };

  wayland.windowManager.hyprland.settings = {
    general = {
      "gaps_in" = 3;
      "gaps_out" = 10;
      "border_size" = 2;
      "col.active_border" = "rgba(33ccffee) rgba(00ff99ee) 45deg";
      "col.inactive_border" = "rgba(595959aa)";
      "layout" = "dwindle";
    };
    
    decoration = {
      "rounding" = 5;
      "active_opacity" = 1.0;
      "inactive_opacity" = 0.9;
      shadow = {
        "enabled" = true;
        "range" = 4;
        "render_power" = 3;
        "color" = "rgba(1a1a1aee)";
      };
      blur = {
        "enabled" = true;
        "size" = 3;
        "passes" = 1;

        "vibrancy" = 0.1696;
      };
    };

    animations = {
      enabled = "yes, please :)";

      bezier = [
        "easeOutQuint, 0.23, 1, 0.32, 1"
        "easeInOutCubic, 0.65, 0.05, 0.36, 1"
        "linear, 0, 0, 1, 1"
        "almostLinear, 0.5, 0.5, 0.75, 1"
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
        "workspaces, 1, 1.94, almostLinear, fade"
        "workspacesIn, 1, 1.21, almostLinear, fade"
        "workspacesOut, 1, 1.94, almostLinear, fade"
        # "zoomFactor, 1, 7, quick" # Uncomment if needed
      ];
    };

    dwindle = {
        "pseudotile" = true; # Master switch for pseudotiling. Enabling is bound to mainMod + P in the keybinds section below
        "preserve_split" = true; # You probably want this
    };

    master.new_status = "master";

    misc = {
      force_default_wallpaper = -1;
      disable_hyprland_logo = false;
    };

    input = {
      kb_layout = "ch";
      kb_options = "caps:escape";

      follow_mouse = 1;
      sensitivity = -0.9;
    };

    cursor = {
      inactive_timeout = 3;
    };

    "$mainMod" = "SUPER";
    "$terminal" = "kitty";
    "$fileManager" = "dolphin";
    "$menu" = "wofi --show drun";
    bind =
      [
        "$mainMod, Q, exec, $terminal"
        "$mainMod, C, killactive"
        "$mainMod, E, exec, $fileManager"
        "$mainMod, v, togglefloating"
        "$mainMod, SPACE, exec, $menu"
        "$mainMod, P, pseudo"
        "$mainMod, T, togglesplit"
        "$mainMod, L, exec, hyprlock"
        ", Print, exec, hyprshot -m region"
        "SHIFT, Print, exec, hyprshot -m region --clipboard-only"

        "$mainMod, H, movefocus, l"
        "$mainMod, I, movefocus, r"
        "$mainMod, K, movefocus, u"
        "$mainMod, J, movefocus, d"

        "$mainMod, S, togglespecialworkspace, magic"
        "$mainMod SHIFT, S, movetoworkspace, special:magic"
      ]
      ++ (
        # workspaces
        # binds $mod + [shift +] {1..9} to [move to] workspace {1..9}
        builtins.concatLists (builtins.genList (i:
            let ws = i + 1;
            in [
              "$mainMod, code:1${toString i}, workspace, ${toString ws}"
              "$mainMod SHIFT, code:1${toString i}, movetoworkspace, ${toString ws}"
            ]
          )
          9)
      );
    bindm =
      [
        "$mainMod, mouse:272, movewindow"
        "$mainMod, mouse:273, resizewindow"
      ];
  };
}
