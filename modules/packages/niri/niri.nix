{ ... }: {
  flake.nixosModules.niri = { config, pkgs, lib, ... }:
    let
      isDesktop = config.dotfiles.desktop.enable;
      isNiriPrimary = isDesktop && config.dotfiles.windowManager.type == "niri";
    in {
      # Always install niri on desktop so it appears in greetd session list
      programs.niri.enable = lib.mkIf isDesktop true;

      programs.xwayland.enable = lib.mkIf isNiriPrimary true;

      xdg.portal = lib.mkIf isNiriPrimary {
        enable = true;
        extraPortals = [ pkgs.xdg-desktop-portal-gtk ];
        config.common.default = [ "niri" "gtk" ];
      };

      security.polkit.enable = lib.mkIf isDesktop true;
      services.gnome.gnome-keyring.enable = lib.mkIf isDesktop true;
      security.pam.services.swaylock = lib.mkIf isDesktop {};

      environment.systemPackages = lib.optionals isDesktop (with pkgs; [
        swaylock
        swayidle
      ]) ++ lib.optionals isNiriPrimary (with pkgs; [
        xwayland-satellite
      ]);

      # Home-manager config
      home-manager.users.${config.dotfiles.user.name} = { lib, pkgs, osConfig, ... }:
        let
          cfg = osConfig.dotfiles.windowManager.settings;
          mainMonitor = osConfig.dotfiles.windowManager.mainMonitor;

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
              position = { x = posX; y = posY; };
              scale = builtins.fromJSON scale;
            };

          monitors = map parseMonitorConfig cfg.monitors;

          left = cfg.left;
          right = cfg.right;
          up = cfg.up;
          down = cfg.down;

          keyToNiri = key:
            if key == "comma" then "Comma"
            else lib.toUpper (lib.substring 0 1 key) + lib.substring 1 (-1) key;

          leftKey = keyToNiri left;
          rightKey = keyToNiri right;
          upKey = keyToNiri up;
          downKey = keyToNiri down;

          mouseAccelSpeed = if cfg.sensitivity != null then cfg.sensitivity else 0.0;
          mouseAccelProfile = if cfg.accel_profile != null
            then if lib.hasPrefix "custom" cfg.accel_profile
              then "adaptive"
              else cfg.accel_profile
            else null;

          generateOutputs = monitors:
            lib.concatMapStringsSep "\n" (mon: ''
              output "${mon.name}" {
                mode "${mon.mode}"
                scale ${toString mon.scale}
                position x=${toString mon.position.x} y=${toString mon.position.y}
              }
            '') monitors;

          generateSpawnCommands = commands:
            lib.concatMapStringsSep "\n" (cmd: ''spawn-at-startup "${cmd}"'') commands;

          baseSpawnCommands =
            (if osConfig.dotfiles.windowManager.statusbar == "waybar" then [ "waybar" ]
            else if osConfig.dotfiles.windowManager.statusbar == "noctalia" then [ "noctalia-shell" ]
            else [])
            ++ [ "pulsemeeter" ];

          allSpawnCommands = baseSpawnCommands ++ cfg.execOnce;
        in lib.mkIf isDesktop {
          home.packages = with pkgs; [ grim slurp ];

          home.sessionVariables = {
            QT_QPA_PLATFORM = "wayland";
            QT_WAYLAND_DISABLE_WINDOWDECORATION = "1";
            GDK_BACKEND = "wayland";
          };

          systemd.user.sessionVariables = {
            GDK_BACKEND = "wayland";
          };

          xdg.configFile."niri/config.kdl".text = ''
            // Generated from NixOS configuration
            // Based on dotfiles.windowManager options

            input {
              keyboard {
                xkb {
                  layout "ch"
                  options "caps:escape"
                }
                numlock
              }

              touchpad {
                tap
                natural-scroll
              }

              mouse {
                ${lib.optionalString (mouseAccelSpeed != 0.0) "accel-speed ${toString mouseAccelSpeed}"}
                ${lib.optionalString (mouseAccelProfile != null) "accel-profile \"${mouseAccelProfile}\""}
              }
            }

            ${lib.optionalString (monitors != []) (generateOutputs monitors)}

            layout {
              gaps 16
              center-focused-column "never"

              preset-column-widths {
                proportion 0.33333
                proportion 0.5
                proportion 0.66667
              }

              default-column-width { proportion 0.5; }

              focus-ring {
                width 4
                active-color "#7fc8ff"
                inactive-color "#505050"
              }

              border {
                off
              }
            }

            ${lib.optionalString (mainMonitor != "") ''
            workspace "tools" {
              open-on-output "${mainMonitor}"
            }
            ''}

            ${lib.optionalString (allSpawnCommands != []) (generateSpawnCommands allSpawnCommands)}

            screenshot-path "~/Pictures/Screenshots/Screenshot from %Y-%m-%d %H-%M-%S.png"

            animations {
              // enabled by default
            }

            window-rule {
              match app-id="org.pulsemeeter.pulsemeeter"
              open-on-workspace "tools"
            }
            window-rule {
              match app-id="com.core447.StreamController"
              open-on-workspace "tools"
            }

            binds {
              Mod+Shift+Slash { show-hotkey-overlay; }

              // Core bindings
              Mod+Q hotkey-overlay-title="Open a Terminal: kitty" { spawn "kitty"; }
              Mod+E hotkey-overlay-title="Yazi file manager" { spawn "kitty" "-e" "yazi"; }
              Mod+SPACE hotkey-overlay-title="Menu" {
                ${if osConfig.dotfiles.windowManager.statusbar == "noctalia"
                  then ''spawn-sh "noctalia-shell ipc call launcher toggle"''
                  else ''spawn "wofi" "--show" "drun" "--sort-order=alphabetical"''}
              }
              Super+Alt+L hotkey-overlay-title="Lock the Screen: swaylock" { spawn "swaylock"; }

              Mod+C repeat=false { close-window; }
              Mod+V { toggle-window-floating; }

              // Focus movement with custom keybindings
              Mod+${leftKey} { focus-column-left; }
              Mod+${rightKey} { focus-column-right; }
              Mod+${upKey} { focus-window-up; }
              Mod+${downKey} { focus-window-down; }

              // Also support arrow keys
              Mod+Left { focus-column-left; }
              Mod+Down { focus-window-down; }
              Mod+Up { focus-window-up; }
              Mod+Right { focus-column-right; }

              // Move windows
              Mod+Shift+${leftKey} { move-column-left; }
              Mod+Shift+${rightKey} { move-column-right; }
              Mod+Shift+${upKey} { move-window-up; }
              Mod+Shift+${downKey} { move-window-down; }

              Mod+Shift+Left { move-column-left; }
              Mod+Shift+Down { move-window-down; }
              Mod+Shift+Up { move-window-up; }
              Mod+Shift+Right { move-column-right; }

              // Focus monitors
              Mod+Ctrl+${leftKey} { focus-monitor-left; }
              Mod+Ctrl+${rightKey} { focus-monitor-right; }
              Mod+Ctrl+${upKey} { focus-monitor-up; }
              Mod+Ctrl+${downKey} { focus-monitor-down; }

              Mod+Ctrl+Left { focus-monitor-left; }
              Mod+Ctrl+Down { focus-monitor-down; }
              Mod+Ctrl+Up { focus-monitor-up; }
              Mod+Ctrl+Right { focus-monitor-right; }

              // Move to monitors
              Mod+Shift+Ctrl+${leftKey} { move-column-to-monitor-left; }
              Mod+Shift+Ctrl+${rightKey} { move-column-to-monitor-right; }
              Mod+Shift+Ctrl+${upKey} { move-column-to-monitor-up; }
              Mod+Shift+Ctrl+${downKey} { move-column-to-monitor-down; }

              Mod+Shift+Ctrl+Left { move-column-to-monitor-left; }
              Mod+Shift+Ctrl+Down { move-column-to-monitor-down; }
              Mod+Shift+Ctrl+Up { move-column-to-monitor-up; }
              Mod+Shift+Ctrl+Right { move-column-to-monitor-right; }

              // Workspaces
              ${builtins.concatStringsSep "\n              " (builtins.genList (i: let ws = i + 1; in "Mod+${toString ws} { focus-workspace ${toString ws}; }") 9)}

              ${builtins.concatStringsSep "\n              " (builtins.genList (i: let ws = i + 1; in "Mod+Shift+${toString ws} { move-column-to-workspace ${toString ws}; }") 9)}

              Mod+F1 { focus-workspace "tools"; }
              Mod+Shift+F1 { move-column-to-workspace "tools"; }

              // Window management
              Mod+R { switch-preset-column-width; }
              Mod+Shift+R { switch-preset-window-height; }
              Mod+Ctrl+R { reset-window-height; }
              Mod+F { maximize-column; }
              Mod+Shift+F { fullscreen-window; }

              // Screenshots
              Print { spawn "sh" "-c" "grim -g \"$(slurp)\" - | swappy -f -"; }
              Shift+Print { spawn "sh" "-c" "grim - | swappy -f -"; }
              Ctrl+Print { spawn "sh" "-c" "grim -g \"$(slurp -o)\" - | swappy -f -"; }

              // Session
              Mod+Escape allow-inhibiting=false { toggle-keyboard-shortcuts-inhibit; }
              Mod+Shift+E { quit; }
              Ctrl+Alt+Delete { quit; }

              // Mouse wheel scrolling
              Mod+WheelScrollDown cooldown-ms=150 { focus-workspace-down; }
              Mod+WheelScrollUp cooldown-ms=150 { focus-workspace-up; }
            }
          '';
        };
    };
}
