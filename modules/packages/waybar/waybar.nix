{ ... }: {
  flake.nixosModules.waybar = { config, pkgs, lib, ... }:
    lib.mkIf (config.dotfiles.desktop.enable && config.dotfiles.windowManager.statusbar == "waybar") {
      home-manager.users.${config.dotfiles.user.name} = { lib, pkgs, osConfig, config, ... }:
        let c = config.lib.stylix.colors.withHashtag; in {
        programs.waybar = {
          enable = true;

          systemd = {
            enable = true;
            targets = [ "hyprland-session.target" ];
          };

          style = ''
            /* ── Stylix palette ──────────────────────────────────────────────── */
            @define-color background ${c.base00};
            @define-color foreground ${c.base05};

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
              color: ${c.base0D};
            }

            #workspaces button:hover {
              color: ${c.base06};
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
              border: 1px solid ${c.base02};
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
            background-color = "${c.base00}";
            text-color = "${c.base05}";
            border-color = "${c.base02}";
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
              border-color = "${c.base02}";
              default-timeout = 3000;
            };
            "urgency=normal" = {
              border-color = "${c.base02}";
              default-timeout = 5000;
            };
            "urgency=high" = {
              border-color = "${c.base08}";
              text-color = "${c.base08}";
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
          /* ── Stylix palette ──────────────────────────────────────────────── */
          @define-color background  ${c.base00};
          @define-color surface     ${c.base01};
          @define-color overlay     ${c.base01};
          @define-color muted       ${c.base03};
          @define-color subtle      ${c.base02};
          @define-color text        ${c.base05};
          @define-color text-bright ${c.base06};
          @define-color accent-blue ${c.base0C};
          @define-color accent-green ${c.base0B};

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
