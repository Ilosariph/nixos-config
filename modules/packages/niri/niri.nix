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
            then ''spawn-sh "noctalia msg session lock"''
            else ''spawn "swaylock"'';

          baseSpawnCommands =
            # noctalia daemon is started by its systemd user service (programs.noctalia.systemd.enable)
            (if osConfig.dotfiles.windowManager.statusbar == "waybar" then [ [ "waybar" ] ]
            else [])
            ++ lib.optionals osConfig.dotfiles.programs._1password.enable [ [ "1password" "--silent" ] ];

          allSpawnCommands = baseSpawnCommands ++ map (s: lib.splitString " " s) cfg.execOnce;

          niri = "${osConfig.programs.niri.package}/bin/niri";

          plezyAppId = ''^com\.edde746\.plezy$'';
          defaultColumnProportion = "0.5";

          # Niri window rules can't match "alone on workspace", so mirror Umbriel's
          # is_alone rule over IPC: a tiled window that is (or becomes) the only
          # tiled window on its workspace gets the full width, and goes back to the
          # default width once another tiled window joins. Windows made full width
          # by hand (or by the Plezy rule) are left alone.
          niriFullWidthAlone = pkgs.writers.writePython3Bin "niri-full-width-alone" { flakeIgnore = [ "E501" "W503" ]; } ''
            import json
            import re
            import subprocess

            NIRI = "${niri}"
            DEFAULT_WIDTH = f"{float('${defaultColumnProportion}') * 100:g}%"
            ALWAYS_FULL = re.compile(${builtins.toJSON plezyAppId})

            windows = {}
            workspace_output = {}
            # Windows this script made full width (reverted when no longer alone)
            auto = set()
            # Workspace id -> id of its sole tiled window
            sole = {}


            def set_width(wid, width):
                subprocess.run([
                    NIRI, "msg", "action", "set-window-width",
                    "--id", str(wid), width,
                ])


            def tiled(ws):
                return [w for w in windows.values()
                        if w["workspace_id"] == ws and not w["is_floating"]]


            def is_full_width(win):
                output = workspace_output.get(win["workspace_id"])
                layout = win.get("layout") or {}
                if output is None or not layout.get("tile_size"):
                    return False
                res = subprocess.run([NIRI, "msg", "--json", "outputs"],
                                     capture_output=True, text=True)
                logical = json.loads(res.stdout).get(output, {}).get("logical")
                return bool(logical) and layout["tile_size"][0] >= 0.9 * logical["width"]


            def sync(ws, new_id=None):
                if ws is None:
                    return
                ts = tiled(ws)
                if len(ts) == 1:
                    win = ts[0]
                    if (sole.get(ws) != win["id"]
                            and win["id"] not in auto
                            and not ALWAYS_FULL.search(win.get("app_id") or "")
                            and (win["id"] == new_id or not is_full_width(win))):
                        set_width(win["id"], "100%")
                        auto.add(win["id"])
                    sole[ws] = win["id"]
                else:
                    for win in ts:
                        if win["id"] in auto:
                            set_width(win["id"], DEFAULT_WIDTH)
                            auto.discard(win["id"])
                    sole.pop(ws, None)


            def reset_sole():
                sole.clear()
                for ws in {w["workspace_id"] for w in windows.values()}:
                    ts = tiled(ws)
                    if len(ts) == 1:
                        sole[ws] = ts[0]["id"]


            stream = subprocess.Popen(
                [NIRI, "msg", "--json", "event-stream"],
                stdout=subprocess.PIPE,
                text=True,
            )
            for line in stream.stdout:
                event = json.loads(line)
                if "WorkspacesChanged" in event:
                    workspace_output = {
                        ws["id"]: ws["output"]
                        for ws in event["WorkspacesChanged"]["workspaces"]
                    }
                elif "WindowsChanged" in event:
                    ws = event["WindowsChanged"]["windows"]
                    windows = {w["id"]: w for w in ws}
                    auto &= windows.keys()
                    reset_sole()
                elif "WindowOpenedOrChanged" in event:
                    win = event["WindowOpenedOrChanged"]["window"]
                    old = windows.get(win["id"])
                    windows[win["id"]] = win
                    if old is None:
                        sync(win["workspace_id"], new_id=win["id"])
                    elif (old["workspace_id"] != win["workspace_id"]
                            or old["is_floating"] != win["is_floating"]):
                        sync(old["workspace_id"])
                        sync(win["workspace_id"])
                elif "WindowLayoutsChanged" in event:
                    for wid, layout in event["WindowLayoutsChanged"]["changes"]:
                        if wid in windows:
                            windows[wid]["layout"] = layout
                elif "WindowClosed" in event:
                    win = windows.pop(event["WindowClosed"]["id"], None)
                    if win is not None:
                        auto.discard(win["id"])
                        sync(win["workspace_id"])
            raise SystemExit(stream.wait() or 1)
          '';
          # maximize-column is a no-op on a column already at 100% width (e.g. one
          # made full width by niri-full-width-alone), so Mod+F toggles by width:
          # full width -> default width, otherwise maximize
          niriToggleFullWidth = pkgs.writeShellApplication {
            name = "niri-toggle-full-width";
            runtimeInputs = [ pkgs.jq ];
            text = ''
              win=$(${niri} msg --json focused-window)
              out_width=$(${niri} msg --json focused-output | jq '.logical.width')
              if jq -e --argjson ow "$out_width" \
                  '.is_floating == false and .layout.tile_size[0] >= 0.9 * $ow' \
                  <<<"$win" >/dev/null; then
                ${niri} msg action set-column-width "$(jq -n '${defaultColumnProportion} * 100')%"
              else
                ${niri} msg action maximize-column
              fi
            '';
          };
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

          systemd.user.services.niri-full-width-alone = {
            Unit = {
              Description = "Full-width windows when alone on a niri workspace";
              BindsTo = [ "graphical-session.target" ];
              PartOf = [ "graphical-session.target" ];
              After = [ "graphical-session.target" ];
            };
            Service = {
              ExecStart = "${niriFullWidthAlone}/bin/niri-full-width-alone";
              Restart = "on-failure";
              RestartSec = 1;
            };
            Install.WantedBy = [ "graphical-session.target" ];
          };

          xdg.configFile."niri/config.kdl".text = ''
            // Generated from NixOS configuration
            // Based on dotfiles.windowManager options

            input {
              keyboard {
                xkb {
                  layout "${osConfig.dotfiles.locale.xkbLayout}"
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
              always-center-single-column

              preset-column-widths {
                proportion 0.33333
                proportion 0.5
                proportion 0.66667
              }

              default-column-width { proportion ${defaultColumnProportion}; }

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

            // Steam games open fullscreen (niri tiles them at partial width otherwise)
            window-rule {
              match app-id=r#"^steam_app_\d+$"#
              open-fullscreen true
            }

            // Plezy always takes the full width
            window-rule {
              match app-id=r#"${plezyAppId}"#
              default-column-width { proportion 1.0; }
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
                  then ''spawn-sh "noctalia msg panel-toggle launcher"''
                  else ''spawn "wofi" "--show" "drun" "--sort-order=alphabetical"''}
              }
              Super+Escape hotkey-overlay-title="Lock the Screen" { ${lockCmd}; }
              // TODO: re-enable Mod+Slash keybind cheatsheet once a v5 noctalia plugin exists (tracked in flake.nix)

              Mod+C repeat=false { close-window; }
              Mod+V { toggle-window-floating; }
              Mod+O { toggle-overview; }
${lib.optionalString (osConfig.dotfiles.audio.routing == "pipewire-virtual") ''
              Mod+Shift+O hotkey-overlay-title="Switch audio output" { spawn "audio-output"; }
              Mod+Shift+M hotkey-overlay-title="Switch audio input" { spawn "audio-input"; }
              Mod+Shift+D hotkey-overlay-title="Switch audio device (in+out)" { spawn "audio-device"; }
              Mod+Shift+A hotkey-overlay-title="Toggle microphone mute" { spawn "mic-mute"; }
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
              Mod+F { spawn "${niriToggleFullWidth}/bin/niri-toggle-full-width"; }
              Mod+Shift+F { fullscreen-window; }
              Mod+T { consume-window-into-column; }
              Mod+Shift+T { expel-window-from-column; }

              // Screenshots
              Print { spawn "screenshot-region"; }
              Shift+Print { spawn "sh" "-c" "grim - | swappy -f -"; }
              Ctrl+Print { spawn "screenshot-region" "-o"; }
              // Same as Print, for keyboards without a Print key (e.g. macbook)
              Mod+Shift+S { spawn "screenshot-region"; }

              // Session
              // Not Mod+Escape: Mod is Super, that chord is the lock above
              Mod+Shift+Escape allow-inhibiting=false { toggle-keyboard-shortcuts-inhibit; }
              Mod+Shift+E { quit; }
              Ctrl+Alt+Delete { quit; }

              // Mouse wheel scrolling
              Mod+WheelScrollDown cooldown-ms=150 { focus-workspace-down; }
              Mod+WheelScrollUp cooldown-ms=150 { focus-workspace-up; }

              // Multimedia / laptop keys (work while the screen is locked)
              XF86AudioRaiseVolume allow-when-locked=true { spawn "wpctl" "set-volume" "-l" "1" "@DEFAULT_AUDIO_SINK@" "5%+"; }
              XF86AudioLowerVolume allow-when-locked=true { spawn "wpctl" "set-volume" "@DEFAULT_AUDIO_SINK@" "5%-"; }
              XF86AudioMute allow-when-locked=true { spawn "wpctl" "set-mute" "@DEFAULT_AUDIO_SINK@" "toggle"; }
              XF86AudioMicMute allow-when-locked=true { spawn "mic-mute"; }
              XF86MonBrightnessUp allow-when-locked=true { spawn "brightnessctl" "-e4" "-n2" "set" "5%+"; }
              XF86MonBrightnessDown allow-when-locked=true { spawn "brightnessctl" "-e4" "-n2" "set" "5%-"; }
              XF86AudioNext allow-when-locked=true { spawn "playerctl" "next"; }
              XF86AudioPause allow-when-locked=true { spawn "playerctl" "play-pause"; }
              XF86AudioPlay allow-when-locked=true { spawn "playerctl" "play-pause"; }
              XF86AudioPrev allow-when-locked=true { spawn "playerctl" "previous"; }
            }
          '';
        };
    };
}
