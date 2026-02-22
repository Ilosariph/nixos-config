{ pkgs, ... }:
{
  programs.waybar = {
    enable = true;

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

        modules-left = [
          "hyprland/workspaces"
        ];

        modules-center = [
          "clock"
        ];

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
            "1" = "1";
            "2" = "2";
            "3" = "3";
            "4" = "4";
            "5" = "5";
            "6" = "6";
            "7" = "7";
            "8" = "8";
            "9" = "9";
            active = "󱓻";
          };
          persistent-workspaces = {
            "1" = [ ];
            "2" = [ ];
            "3" = [ ];
            "4" = [ ];
            "5" = [ ];
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
          format-icons = [
            "󰤯"
            "󰤟"
            "󰤢"
            "󰤥"
            "󰤨"
          ];
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
          format = "{capacity}% {icon}";
          format-discharging = "{icon}";
          format-charging = "{icon}";
          format-plugged = "";
          format-icons = {
            charging = [
              "󰢜"
              "󰂆"
              "󰂇"
              "󰂈"
              "󰢝"
              "󰂉"
              "󰢞"
              "󰂊"
              "󰂋"
              "󰂅"
            ];
            default = [
              "󰁺"
              "󰁻"
              "󰁼"
              "󰁽"
              "󰁾"
              "󰁿"
              "󰂀"
              "󰂁"
              "󰂂"
              "󰁹"
            ];
          };
          format-full = "Charged ";
          tooltip-format-discharging = "{power:>1.0f}W↓ {capacity}%";
          tooltip-format-charging = "{power:>1.0f}W↑ {capacity}%";
          states = {
            warning = 20;
            critical = 10;
          };
        };

        bluetooth = {
          format = "󰂯";
          format-disabled = "󰂲";
          format-connected = "";
          tooltip-format = "Devices connected: {num_connections}";
          on-click = "blueberry";
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

        tray = {
          spacing = 13;
        };

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
}
