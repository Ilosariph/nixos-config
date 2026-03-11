{ ... }: {
  flake.nixosModules.niri = { config, pkgs, lib, ... }:
    let
      isNiri = config.dotfiles.desktop.enable && config.dotfiles.windowManager.type == "niri";
    in {
      # System config
      programs.niri.enable = lib.mkIf isNiri true;

      xdg.portal = lib.mkIf isNiri {
        enable = true;
        extraPortals = [ pkgs.xdg-desktop-portal-gtk ];
        config.common.default = [ "niri" "gtk" ];
      };

      security.polkit.enable = lib.mkIf isNiri true;
      services.gnome.gnome-keyring.enable = lib.mkIf isNiri true;
      security.pam.services.swaylock = lib.mkIf isNiri {};

      environment.systemPackages = lib.optionals isNiri (with pkgs; [
        swaylock
        swayidle
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

          baseSpawnCommands = if osConfig.dotfiles.windowManager.statusbar == "waybar"
            then [ "waybar" ]
            else [];

          allSpawnCommands = baseSpawnCommands ++ cfg.execOnce;
        in lib.mkIf isNiri {
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

            ${lib.optionalString (allSpawnCommands != []) (generateSpawnCommands allSpawnCommands)}

            screenshot-path "~/Pictures/Screenshots/Screenshot from %Y-%m-%d %H-%M-%S.png"

            animations {
              // enabled by default
            }

            binds {
              Mod+Shift+Slash { show-hotkey-overlay; }

              // Core bindings
              Mod+Q hotkey-overlay-title="Open a Terminal: kitty" { spawn "kitty"; }
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
              Mod+Ctrl+${leftKey} { move-column-left; }
              Mod+Ctrl+${rightKey} { move-column-right; }
              Mod+Ctrl+${upKey} { move-window-up; }
              Mod+Ctrl+${downKey} { move-window-down; }

              Mod+Ctrl+Left { move-column-left; }
              Mod+Ctrl+Down { move-window-down; }
              Mod+Ctrl+Up { move-window-up; }
              Mod+Ctrl+Right { move-column-right; }

              // Focus monitors
              Mod+Shift+${leftKey} { focus-monitor-left; }
              Mod+Shift+${rightKey} { focus-monitor-right; }
              Mod+Shift+${upKey} { focus-monitor-up; }
              Mod+Shift+${downKey} { focus-monitor-down; }

              Mod+Shift+Left { focus-monitor-left; }
              Mod+Shift+Down { focus-monitor-down; }
              Mod+Shift+Up { focus-monitor-up; }
              Mod+Shift+Right { focus-monitor-right; }

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
              Mod+1 { focus-workspace 1; }
              Mod+2 { focus-workspace 2; }
              Mod+3 { focus-workspace 3; }
              Mod+4 { focus-workspace 4; }
              Mod+5 { focus-workspace 5; }
              Mod+6 { focus-workspace 6; }
              Mod+7 { focus-workspace 7; }
              Mod+8 { focus-workspace 8; }
              Mod+9 { focus-workspace 9; }

              Mod+Ctrl+1 { move-column-to-workspace 1; }
              Mod+Ctrl+2 { move-column-to-workspace 2; }
              Mod+Ctrl+3 { move-column-to-workspace 3; }
              Mod+Ctrl+4 { move-column-to-workspace 4; }
              Mod+Ctrl+5 { move-column-to-workspace 5; }
              Mod+Ctrl+6 { move-column-to-workspace 6; }
              Mod+Ctrl+7 { move-column-to-workspace 7; }
              Mod+Ctrl+8 { move-column-to-workspace 8; }
              Mod+Ctrl+9 { move-column-to-workspace 9; }

              // Window management
              Mod+R { switch-preset-column-width; }
              Mod+Shift+R { switch-preset-window-height; }
              Mod+Ctrl+R { reset-window-height; }
              Mod+F { maximize-column; }
              Mod+Shift+F { fullscreen-window; }

              // Screenshots
              Print { screenshot; }
              Ctrl+Print { screenshot-screen; }
              Alt+Print { screenshot-window; }

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
