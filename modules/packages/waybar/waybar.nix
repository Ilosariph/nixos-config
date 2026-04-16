{ ... }: {
  flake.nixosModules.waybar = { config, pkgs, lib, ... }:
    lib.mkIf (config.dotfiles.desktop.enable && config.dotfiles.windowManager.statusbar == "waybar") {
      home-manager.users.${config.dotfiles.user.name} = { lib, pkgs, osConfig, ... }: {
        programs.waybar = {
          enable = true;

          systemd = {
            enable = true;
            targets = [ "hyprland-session.target" ];
          };

          style = ''
            /* ── Tokyo Night colour palette ─────────────────────────────────── */
            @define-color background #1a1b26;
            @define-color foreground #a9b1d6;

            * {
              color: @foreground;
              border: none;
              border-radius: 0;
              min-height: 0;
              font-family: JetBrainsMono Nerd Font, JetBrains Mono, monospace;
              font-size: 14px;
            }

            window#waybar {
              background-color: @background;
            }

            #workspaces {
              margin-left: 7px;
            }

            #workspaces button {
              all: initial;
              color: @foreground;
              padding: 2px 6px;
              margin-right: 3px;
            }

            #workspaces button.active,
            #workspaces button.focused {
              color: #7aa2f7;
            }

            #workspaces button:hover {
              color: #c0caf5;
            }

            #custom-dropbox,
            #cpu,
            #power-profiles-daemon,
            #battery,
            #network,
            #bluetooth,
            #wireplumber,
            #tray,
            #clock {
              background-color: transparent;
              min-width: 12px;
              margin-right: 13px;
            }

            tooltip {
              background-color: @background;
              border: 1px solid #414868;
              padding: 2px;
            }

            tooltip label {
              color: @foreground;
              padding: 2px;
            }
          '';

          settings = [
            {
              layer = "top";
              position = "top";
              spacing = 0;
              height = 26;

              modules-left = [ "hyprland/workspaces" ];
              modules-center = [ "clock" ];
              modules-right = [
                "tray"
                "bluetooth"
                "network"
                "wireplumber"
                "cpu"
                "power-profiles-daemon"
                "battery"
              ];

              "hyprland/workspaces" = {
                on-click = "activate";
                format = "{icon}";
                format-icons = {
                  default = "";
                  "1" = "1"; "2" = "2"; "3" = "3"; "4" = "4"; "5" = "5";
                  "6" = "6"; "7" = "7"; "8" = "8"; "9" = "9";
                  active = "󱓻";
                };
                persistent-workspaces = {
                  "1" = []; "2" = []; "3" = []; "4" = []; "5" = [];
                };
              };

              cpu = {
                interval = 5;
                format = "󰍛";
                on-click = "kitty -e btop";
              };

              clock = {
                format = "{:%A %H:%M}";
                format-alt = "{:%d %B W%V %Y}";
                tooltip = false;
              };

              network = {
                format-icons = [ "󰤯" "󰤟" "󰤢" "󰤥" "󰤨" ];
                format = "{icon}";
                format-wifi = "{icon}";
                format-ethernet = "󰀂";
                format-disconnected = "󰖪";
                tooltip-format-wifi = "{essid} ({frequency} GHz)\n⇣{bandwidthDownBytes}  ⇡{bandwidthUpBytes}";
                tooltip-format-ethernet = "⇣{bandwidthDownBytes}  ⇡{bandwidthUpBytes}";
                tooltip-format-disconnected = "Disconnected";
                interval = 3;
                nospacing = 1;
                on-click = "nm-connection-editor";
              };

              battery = {
                interval = 5;
                format = "{icon} {capacity}%";
                format-discharging = "{icon} {capacity}%";
                format-charging = " {capacity}%";
                format-plugged = " {capacity}%";
                format-icons = {
                  charging = [ "󰢜" "󰂆" "󰂇" "󰂈" "󰢝" "󰂉" "󰢞" "󰂊" "󰂋" "󰂅" ];
                  default = [ "󰁺" "󰁻" "󰁼" "󰁽" "󰁾" "󰁿" "󰂀" "󰂁" "󰂂" "󰁹" ];
                };
                format-full = "Charged ";
                tooltip-format-discharging = "{power:>1.0f}W↓ {capacity}%";
                tooltip-format-charging = "{power:>1.0f}W↑ {capacity}%";
                states = { warning = 20; critical = 10; };
              };

              bluetooth = {
                format = "󰂯";
                format-disabled = "󰂲";
                format-connected = "";
                tooltip-format = "Devices connected: {num_connections}";
                on-click = "blueman-manager";
              };

              wireplumber = {
                format = "";
                format-muted = "󰝟";
                scroll-step = 5;
                on-click = "pavucontrol";
                tooltip-format = "Playing at {volume}%";
                on-click-right = "wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle";
                max-volume = 150;
              };

              tray = { spacing = 13; };

              power-profiles-daemon = {
                format = "{icon}";
                tooltip-format = "Power profile: {profile}";
                tooltip = true;
                format-icons = {
                  power-saver = "󰡳";
                  balanced = "󰊚";
                  performance = "󰡴";
                };
              };
            }
          ];
        };

        systemd.user.services.waybar = {
          Unit = {
            Wants = [
              "xdg-desktop-portal.service"
              "xdg-desktop-portal-hyprland.service"
              "xdg-desktop-portal-gtk.service"
            ];
            After = [
              "xdg-desktop-portal.service"
              "xdg-desktop-portal-hyprland.service"
              "xdg-desktop-portal-gtk.service"
            ];
          };
          Service = {
            ExecStartPre = "${pkgs.coreutils}/bin/sleep 2";
            RestartSec = 5;
          };
        };

        # Mako notification daemon
        services.mako = {
          enable = true;
          settings = {
            font = "JetBrainsMono Nerd Font 12";
            background-color = "#1a1b26";
            text-color = "#a9b1d6";
            border-color = "#3b4261";
            border-radius = 8;
            border-size = 1;
            padding = "12,16";
            margin = "10";
            width = 360;
            max-visible = 5;
            sort = "-time";
            layer = "overlay";
            anchor = "top-right";
            default-timeout = 5000;

            "urgency=low" = {
              border-color = "#3b4261";
              default-timeout = 3000;
            };
            "urgency=normal" = {
              border-color = "#3b4261";
              default-timeout = 5000;
            };
            "urgency=high" = {
              border-color = "#f7768e";
              text-color = "#f7768e";
              default-timeout = 0;
            };
          };
        };

        # Wofi application launcher
        xdg.configFile."wofi/config".text = ''
          width=620
          height=420
          location=center
          show=drun
          prompt=Search...
          filter_rate=100
          allow_markup=true
          no_actions=true
          halign=fill
          orientation=vertical
          content_halign=fill
          insensitive=true
          allow_images=true
          image_size=36
          gtk_dark=true
          term=kitty
        '';

        xdg.configFile."wofi/style.css".text = ''
          /* ── Tokyo Night palette ─────────────────────────────────────────── */
          @define-color background  #1a1b26;
          @define-color surface     #24283b;
          @define-color overlay     #2a2b3d;
          @define-color muted       #595959;
          @define-color subtle      #414868;
          @define-color text        #a9b1d6;
          @define-color text-bright #c0caf5;
          @define-color accent-blue #33ccff;
          @define-color accent-green #00ff99;

          * {
            font-family: JetBrainsMono Nerd Font, JetBrains Mono, monospace;
            font-size: 14px;
            color: @text;
          }

          window { background: transparent; }

          #window {
            background-color: @background;
            border-radius: 12px;
            border: 2px solid @accent-blue;
            box-shadow: 0 8px 32px alpha(#000000, 0.6);
          }

          #outer-box {
            background-color: transparent;
            padding: 12px;
            border-radius: 12px;
          }

          #input {
            background-color: @surface;
            color: @text-bright;
            border: 1px solid @subtle;
            border-radius: 8px;
            padding: 8px 12px;
            margin-bottom: 8px;
            caret-color: @accent-blue;
            outline: none;
          }

          #input:focus {
            border-color: @accent-blue;
            box-shadow: 0 0 0 1px alpha(@accent-blue, 0.4);
          }

          #scroll { background-color: transparent; border: none; margin: 0; padding: 0; }
          #inner-box { background-color: transparent; }

          #entry {
            background-color: transparent;
            border-radius: 8px;
            padding: 6px 10px;
            margin: 2px 0;
            transition: background-color 100ms ease;
          }

          #entry:hover { background-color: @overlay; }

          #entry:selected {
            background-color: @overlay;
            border-left: 2px solid @accent-blue;
          }

          #entry:selected #text { color: @text-bright; }

          #text { color: @text; margin-left: 6px; }
          #img { margin-right: 4px; border-radius: 4px; }
        '';
      };
    };
}
