{ ... }: {
  flake.nixosModules.niri = { config, pkgs, lib, ... }:
    let
      isDesktop = config.dotfiles.desktop.enable;
      isNiriPrimary = isDesktop && config.dotfiles.windowManager.type == "niri";
    in {
      programs.niri.enable = lib.mkIf isNiriPrimary true;

      programs.xwayland.enable = lib.mkIf isNiriPrimary true;

      xdg.portal = lib.mkIf isNiriPrimary {
        enable = true;
        extraPortals = [ pkgs.xdg-desktop-portal-gtk ];
        config.common.default = [ "niri" "gtk" ];
      };

      security.polkit.enable = lib.mkIf isNiriPrimary true;
      services.gnome.gnome-keyring.enable = lib.mkIf isNiriPrimary true;
      security.pam.services.swaylock = lib.mkIf isNiriPrimary {};
      security.pam.services.login = lib.mkIf isNiriPrimary { enableGnomeKeyring = true; };

      environment.systemPackages = lib.optionals isNiriPrimary (with pkgs; [
        swaylock
        swayidle
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


          generateOutputs = monitors:
            lib.concatMapStringsSep "\n" (mon: ''
              output "${mon.name}" {
                mode "${mon.mode}"
                scale ${toString mon.scale}
                position x=${toString mon.position.x} y=${toString mon.position.y}
              }
            '') monitors;

          generateSpawnCommands = commands:
            lib.concatMapStringsSep "\n" (args:
              ''spawn-at-startup ${lib.concatMapStringsSep " " (a: ''"${a}"'') args}''
            ) commands;

          lockCmd =
            if osConfig.dotfiles.windowManager.statusbar == "noctalia"
            then ''spawn-sh "noctalia-shell ipc call lockScreen lock"''
            else ''spawn "swaylock"'';

          baseSpawnCommands =
            (if osConfig.dotfiles.windowManager.statusbar == "waybar" then [ [ "waybar" ] ]
            else if osConfig.dotfiles.windowManager.statusbar == "noctalia" then [ [ "noctalia-shell" ] ]
            else [])
            ++ lib.optionals osConfig.dotfiles.programs._1password.enable [ [ "1password" "--silent" ] ];

          allSpawnCommands = baseSpawnCommands ++ map (s: lib.splitString " " s) cfg.execOnce;
        in lib.mkIf isNiriPrimary {
          home.packages = with pkgs; [ grim slurp ];

          home.sessionVariables = {
            QT_QPA_PLATFORM = "wayland";
            QT_WAYLAND_DISABLE_WINDOWDECORATION = "1";
            GDK_BACKEND = "wayland";
            GSK_RENDERER = "ngl";
            DISPLAY = ":0";
          };

          systemd.user.sessionVariables = {
            GDK_BACKEND = "wayland";
            GSK_RENDERER = "ngl";
            XDG_SESSION_TYPE = "wayland";
            XDG_CURRENT_DESKTOP = "niri";
            NIXOS_OZONE_WL = "1";
          };

          systemd.user.services.xwayland-satellite = lib.mkIf isNiriPrimary {
            Unit = {
              Description = "Xwayland outside any Wayland compositor";
              BindsTo = [ "graphical-session.target" ];
              PartOf = [ "graphical-session.target" ];
              After = [ "graphical-session.target" ];
            };
            Service = {
              ExecStart = "${pkgs.xwayland-satellite}/bin/xwayland-satellite :0";
              Restart = "on-failure";
            };
            Install.WantedBy = [ "graphical-session.target" ];
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
                ${lib.optionalString osConfig.dotfiles.programs.yeetmouse.enable ''accel-speed 0
                accel-profile "flat"''}
              }

              focus-follows-mouse max-scroll-amount="0%"
            }

            gestures {
              hot-corners {
                off
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
                width 2
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

            environment {
              DISPLAY ":0"
              XDG_SESSION_TYPE "wayland"
              XDG_CURRENT_DESKTOP "niri"
              NIXOS_OZONE_WL "1"
            }

            screenshot-path "~/Pictures/Screenshots/Screenshot from %Y-%m-%d %H-%M-%S.png"

            animations {
              // enabled by default
            }

            prefer-no-csd

            window-rule {
              geometry-corner-radius 8
              clip-to-geometry true
            }

            ${lib.optionalString (cfg.monitors != []) (let
              rightMonitor = (lib.last (map parseMonitorConfig cfg.monitors)).name;
            in ''
            window-rule {
              match app-id="com.core447.StreamController"
              open-on-output "${rightMonitor}"
            }
            '')}

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
              Super+Alt+L hotkey-overlay-title="Lock the Screen" { ${lockCmd}; }
              Super+Escape hotkey-overlay-title="Lock the Screen" { ${lockCmd}; }
              ${lib.optionalString (osConfig.dotfiles.windowManager.statusbar == "noctalia")
                ''Mod+Slash hotkey-overlay-title="Keybind Cheatsheet" { spawn-sh "noctalia-shell ipc call plugin:keybind-cheatsheet toggle"; }''}

              Mod+C repeat=false { close-window; }
              Mod+V { toggle-window-floating; }
              Mod+O { toggle-overview; }
${lib.optionalString (osConfig.dotfiles.audio.routing == "pipewire-virtual") ''
              Mod+Shift+O hotkey-overlay-title="Switch audio output" { spawn "audio-output"; }
''}

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
              Mod+T { consume-window-into-column; }
              Mod+Shift+T { expel-window-from-column; }

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
