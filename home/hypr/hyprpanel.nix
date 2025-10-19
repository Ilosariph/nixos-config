{ inputs, ... }:
{
  programs.hyprpanel = {
	enable = true;
	settings = {
      bar.layouts = {
        "0" = {
          left = [ "dashboard" "workspaces" ];
          middle = [ "media" ];
          right = [ "volume" "network" "bluetooth" "systray" "clock" "notifications" ];
        };
		"1" = {
          left = [ "dashboard" "workspaces" ];
          middle = [ "media" ];
          right = [ "clock" "notifications" ];
        };
		"2" = {
          left = [ "dashboard" "workspaces" ];
          middle = [ "media" ];
          right = [ "clock" "notifications" ];
        };
      };
	  theme.bar.buttons.enableBorders = true;
	  bar.workspaces.applicationIconMap = {};
	  bar.workspaces.workspaceIconMap = {};
	  bar.workspaces.workspaces = 5;
	  bar.workspaces.scroll_speed = 5;
	  bar.volume.label = true;
	  bar.network.showWifiInfo = false;
	  bar.clock.format = "%a %b %d  %H:%M";
	  bar.media.show_label = true;
	  bar.media.format = "{artist: - }{title}";
	  bar.notifications.show_total = true;
	  bar.media.show_active_only = true;
	  bar.launcher.autoDetectIcon = true;
	  menus.transition = "crossfade";
	  theme.bar.menus.enableShadow = false;
	  menus.media.hideAuthor = false;
	  menus.media.displayTimeTooltip = false;
	  menus.media.displayTime = false;
	  notifications.ignore = [
		"spotify"
	  ];
	  notifications.active_monitor = false;
	  notifications.showActionsOnHover = false;
	  theme.osd.duration = 2500;
	  theme.osd.enable = false;
	  theme.bar.transparent = true;
	  theme.font.size = "16px";
	  menus.volume.raiseMaximumVolume = true;
	  menus.clock.time.military = true;
	  menus.clock.weather.unit = "metric";
	  menus.clock.weather.location = "47.436424,9.130866";
	  menus.clock.weather.key = "/etc/nixos/weather.json";
	  menus.dashboard.controls.enabled = true;
	  menus.dashboard.shortcuts.left.shortcut1.tooltip = "Firefox";
	  menus.dashboard.shortcuts.left.shortcut1.command = "firefox";
	  menus.dashboard.shortcuts.left.shortcut1.icon = "";
	  menus.dashboard.directories.enabled = false;
	  menus.dashboard.shortcuts.enabled = false;
	  menus.dashboard.stats.enabled = false;
	  bar.customModules.cpuTemp.sensor = "/dev/cpu_temp";
	  menus.clock.weather.interval = 120000;
	};
  };
}
