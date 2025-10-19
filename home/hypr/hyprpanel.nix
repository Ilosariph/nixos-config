{ inputs, ... }:
{
  programs.hyprpanel = {
	enable = true;
	settings = {
      bar.layouts = {
        "DP-1" = {
          left = [ "dashboard" "workspaces" ];
          middle = [ "media" ];
          right = [ "volume" "network" "bluetooth" "clock" "notifications" ];
        };
		"DP-3" = {
          left = [ "dashboard" "workspaces" ];
          middle = [ "media" ];
          right = [ "clock" "notifications" ];
        };
		"HDMI-A-1" = {
          left = [ "dashboard" "workspaces" ];
          middle = [ "media" ];
          right = [ "clock" "notifications" ];
        };
      };

      bar.launcher.autoDetectIcon = true;
      bar.workspaces.show_icons = true;

      menus.clock = {
        time = {
          military = true;
          hideSeconds = true;
        };
        weather.unit = "metric";
      };
	
	  menus.systray.ignoreList = [ "battery" ];

      menus.dashboard.directories.enabled = false;
      menus.dashboard.stats.enable_gpu = true;

      theme.bar.transparent = true;

      theme.font = {
        name = "CaskaydiaCove NF";
        size = "16px";
      };
	};
  };
}
