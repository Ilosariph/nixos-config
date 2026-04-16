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

          spawnLine = cmd:
            let parts = lib.splitString " " cmd;
            in "spawn-at-startup ${lib.concatMapStringsSep " " (p: ''"${p}"'') parts}";

          baseSpawnCommands =
            [
              "clipse -listen"
              "wl-clip-persist --clipboard regular"
              "nm-applet --indicator"
              "1password --silent"
            ]
            ++ lib.optionals (osConfig.dotfiles.windowManager.statusbar == "waybar") [
              "waybar"
              "hyprpaper"
            ]
            ++ lib.optionals (osConfig.dotfiles.windowManager.statusbar == "noctalia") [
              "noctalia-shell"
            ];

          allSpawnCommands = baseSpawnCommands ++ cfg.execOnce;

          spawnLines = lib.concatMapStringsSep "\n" spawnLine allSpawnCommands;

          swayidleLine = ''spawn-at-startup "swayidle" "-w" "timeout" "300" "swaylock -f" "timeout" "330" "niri msg action power-off-monitors" "resume" "niri msg action power-on-monitors" "before-sleep" "swaylock -f"'';

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

            ${swayidleLine}
            ${spawnLines}

            screenshot-path "~/Pictures/Screenshots/Screenshot from %Y-%m-%d %H-%M-%S.png"

            animations {}

            window-rule {
              match app-id="org.pulseaudio.pavucontrol"
              open-floating true
            }

            window-rule {
              match app-id="blueman-manager"
              open-floating true
            }

            window-rule {
              match app-id="clipse"
              open-floating true
              default-column-width { fixed 622; }
            }

            binds {
              Mod+Shift+Slash { show-hotkey-overlay; }

              // Core bindings
              Mod+Q hotkey-overlay-title="Open a Terminal: kitty" { spawn "kitty"; }
              Mod+E hotkey-overlay-title="File Manager: yazi" { spawn "kitty" "-e" "yazi"; }
              Mod+Space hotkey-overlay-title="Menu" {
                ${if osConfig.dotfiles.windowManager.statusbar == "noctalia"
                  then ''spawn "sh" "-c" "noctalia-shell ipc call launcher toggle"''
                  else ''spawn "wofi" "--show" "drun" "--sort-order=alphabetical"''}
              }

              // Lock / session
              Mod+Alt+L hotkey-overlay-title="Lock: swaylock" { spawn "swaylock"; }
              Mod+Escape { spawn "swaylock"; }
              Mod+Shift+Escape repeat=false { quit; }
              Mod+Shift+E repeat=false { quit; }
              Mod+Ctrl+Escape repeat=false { spawn "sh" "-c" "reboot"; }
              Mod+Shift+Ctrl+Escape repeat=false { spawn "sh" "-c" "systemctl poweroff"; }
              Mod+Ctrl+Slash allow-inhibiting=false { toggle-keyboard-shortcuts-inhibit; }

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

              // Move column to monitor
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

              Mod+Shift+1 { move-column-to-workspace 1; }
              Mod+Shift+2 { move-column-to-workspace 2; }
              Mod+Shift+3 { move-column-to-workspace 3; }
              Mod+Shift+4 { move-column-to-workspace 4; }
              Mod+Shift+5 { move-column-to-workspace 5; }
              Mod+Shift+6 { move-column-to-workspace 6; }
              Mod+Shift+7 { move-column-to-workspace 7; }
              Mod+Shift+8 { move-column-to-workspace 8; }
              Mod+Shift+9 { move-column-to-workspace 9; }

              // Window sizing
              Mod+R { switch-preset-column-width; }
              Mod+Shift+R { switch-preset-window-height; }
              Mod+Ctrl+R { reset-window-height; }
              Mod+F { maximize-column; }
              Mod+Shift+F { fullscreen-window; }

              // Screenshots
              Print { screenshot; }
              Shift+Print { screenshot-screen; }
              Ctrl+Print { screenshot-window; }

              // Clipboard manager (clipse)
              Mod+Shift+V { spawn "kitty" "--class" "clipse" "-e" "clipse"; }

              ${lib.optionalString (osConfig.dotfiles.windowManager.statusbar == "waybar")
                ''Mod+Shift+Space { spawn "sh" "-c" "pkill -SIGUSR1 waybar"; }''}

              // Mouse wheel workspace switching
              Mod+WheelScrollDown cooldown-ms=150 { focus-workspace-down; }
              Mod+WheelScrollUp cooldown-ms=150 { focus-workspace-up; }

              // Media keys
              XF86AudioRaiseVolume allow-when-locked=true { spawn "wpctl" "set-volume" "-l" "1" "@DEFAULT_AUDIO_SINK@" "5%+"; }
              XF86AudioLowerVolume allow-when-locked=true { spawn "wpctl" "set-volume" "@DEFAULT_AUDIO_SINK@" "5%-"; }
              XF86AudioMute allow-when-locked=true { spawn "wpctl" "set-mute" "@DEFAULT_AUDIO_SINK@" "toggle"; }
              XF86AudioMicMute allow-when-locked=true { spawn "wpctl" "set-mute" "@DEFAULT_AUDIO_SOURCE@" "toggle"; }
              XF86MonBrightnessUp { spawn "brightnessctl" "-e4" "-n2" "set" "5%+"; }
              XF86MonBrightnessDown { spawn "brightnessctl" "-e4" "-n2" "set" "5%-"; }
              XF86AudioNext allow-when-locked=true { spawn "playerctl" "next"; }
              XF86AudioPrev allow-when-locked=true { spawn "playerctl" "previous"; }
              XF86AudioPlay allow-when-locked=true { spawn "playerctl" "play-pause"; }
              XF86AudioPause allow-when-locked=true { spawn "playerctl" "play-pause"; }
            }
          '';
        };
    };
}
