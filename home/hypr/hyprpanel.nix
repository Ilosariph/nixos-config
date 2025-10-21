{ inputs, ... }:
{
  programs.hyprpanel = {
	enable = true;
	settings = {
	  bar = {
	    volume.label = true;
	    network.showWifiInfo = false;
	    clock.format = "%a %b %d  %H:%M";
	    notifications.show_total = true;
	    launcher.autoDetectIcon = true;
	    customModules.cpuTemp.sensor = "/dev/cpu_temp";
	    layouts = {
          "0" = {
            left = [ "dashboard" "workspaces" ];
            middle = [ "media" ];
            right = [ "volume" "network" "bluetooth" "systray" "clock" "notifications" ];
          };
		  "1" = {
            left = [ "dashboard" "workspaces" ];
            middle = [ "media" ];
            right = [ "volume" "clock" "notifications" ];
          };
		  "2" = {
            left = [ "dashboard" "workspaces" ];
            middle = [ "media" ];
            right = [ "volume" "clock" "notifications" ];
          };
        };
		workspaces = {
	      applicationIconMap = {};
	      workspaceIconMap = {};
	      workspaces = 5;
	      scroll_speed = 5;
		};
	    media = {
		  show_label = true;
	      format = "{artist: - }{title}";
	      show_active_only = true;
		};
	  };
	  menus = {
	    transition = "crossfade";
	    volume.raiseMaximumVolume = true;
		media = {
	      hideAuthor = false;
	      displayTimeTooltip = false;
	      displayTime = false;
		};
		clock = {
	      time.military = true;
		  weather = {
	        unit = "metric";
	        location = "47.436424,9.130866";
	        key = "/etc/nixos/weather.json";
	        interval = 120000;
		  };
		};
		dashboard = {
	      controls.enabled = true;
	      directories.enabled = false;
	      stats.enabled = false;
		  shortcuts = {
	        enabled = false;
	  		left.shortcut1.tooltip = "Firefox";
	  		left.shortcut1.command = "firefox";
	  		left.shortcut1.icon = "";
		  };
		};
	  };
	  notifications = {
	    ignore = [
		  "spotify"
	    ];
	    active_monitor = false;
	    showActionsOnHover = false;
	  };
	  theme = {
	    font.size = "16px";
		bar = {
		  transparent = true;
	      menus.enableShadow = false;
	      buttons.enableBorders = true;
		};
		osd = {
		  enable = false;
		  duration = 2500;
		};
	  };
	};
  };
}
