{ config, pkgs, ... }:
let
  wallpaperPath = config.home.sessionVariables.WALLPAPER_DIR;
  randomWallpaperScript = pkgs.writeShellScriptBin "random-wallpaper" (builtins.readFile ./hyprpaper/random_background.sh);
in {
  programs.kitty.enable = true;
  wayland.windowManager.hyprland.enable = true;

  imports = [ ./hyprpaper/hyprpaper.nix ];
  home.packages = [ randomWallpaperScript ];

  # Optional, hint Electron apps to use Wayland:
  # home.sessionVariables.NIXOS_OZONE_WL = "1";

  wayland.windowManager.hyprland.settings = {
		exec-once = [
			"hyprpaper"
			"hypridle"
			"systemctl --user start hyprpolkitagent"
			"gsettings set org.gnome.desktop.interface cursor-theme '${config.home.pointerCursor.name}'"
			"gsettings set org.gnome.desktop.interface cursor-size ${toString config.home.pointerCursor.size}"
			"pulsemeeter"
			"streamcontroller"
			"qpwgraph"
			"${randomWallpaperScript}/bin/random-wallpaper ${wallpaperPath} > /home/simon/random-wallpaper-script.txt 2>&1"
			"systemctl --user import-environment PATH"
			"systemctl --user import-environment XDG_DATA_DIRS"
			"bash -c 'wl-paste --watch cliphist store &'"
			"easyeffects"
		];

		general = {
			"gaps_in" = 3;
			"gaps_out" = 10;
			"border_size" = 2;
			"col.active_border" = "rgba(33ccffee) rgba(00ff99ee) 45deg";
			"col.inactive_border" = "rgba(595959aa)";
			"layout" = "dwindle";
		};

		windowrulev2 = [
			"opacity 1.0 override 1.0 override, class:^(com.interversehq.qView)$"
			"opacity 1.0 override 1.0 override, class:^(mpv)$"
			"noborder, class:^(kitty)$"
			"float, class:^(org.quickshell)$"
		];

		decoration = {
			"rounding" = 5;
			"active_opacity" = 1.0;
			"inactive_opacity" = 0.9;
			shadow = {
				"enabled" = true;
				"range" = 4;
				"render_power" = 3;
				"color" = "rgba(1a1a1aee)";
			};
			blur = {
				"enabled" = true;
				"size" = 3;
				"passes" = 1;

				"vibrancy" = 0.1696;
			};
		};

		animations = {
			enabled = "yes, please :)";

			bezier = [
				"easeOutQuint, 0.23, 1, 0.32, 1"
				"easeInOutCubic, 0.65, 0.05, 0.36, 1"
				"linear, 0, 0, 1, 1"
				"almostLinear, 0.5, 0.5, 0.75, 1"
				"quick, 0.15, 0, 0.1, 1"
			];

			animation = [
				"global, 1, 10, default"
				"border, 1, 5.39, easeOutQuint"
				"windows, 1, 4.79, easeOutQuint"
				"windowsIn, 1, 4.1, easeOutQuint, popin 87%"
				"windowsOut, 1, 1.49, linear, popin 87%"
				"fadeIn, 1, 1.73, almostLinear"
				"fadeOut, 1, 1.46, almostLinear"
				"fade, 1, 3.03, quick"
				"layers, 1, 3.81, easeOutQuint"
				"layersIn, 1, 4, easeOutQuint, fade"
				"layersOut, 1, 1.5, linear, fade"
				"fadeLayersIn, 1, 1.79, almostLinear"
				"fadeLayersOut, 1, 1.39, almostLinear"
				"workspaces, 1, 1.94, almostLinear, fade"
				"workspacesIn, 1, 1.21, almostLinear, fade"
				"workspacesOut, 1, 1.94, almostLinear, fade"
				# "zoomFactor, 1, 7, quick" # Uncomment if needed
			];
		};

		dwindle = {
			"pseudotile" = true; # Master switch for pseudotiling. Enabling is bound to mainMod + P in the keybinds section below
			"preserve_split" = true; # You probably want this
		};

		master.new_status = "master";

		misc = {
			force_default_wallpaper = -1;
			disable_hyprland_logo = false;
		};

		input = {
			kb_layout = "ch";
			kb_options = "caps:escape";

			follow_mouse = 1;
			
			touchpad = {
				natural_scroll = true;
			};
		};

		cursor = {
			inactive_timeout = 3;
		};

		# Variables for programs. Variables for left, right, up and down are defined in ../../machines/{machine}/home.nix
		"$mainMod" = "SUPER";
		"$terminal" = "kitty";
		"$fileManager" = "kitty yazi";
		"$menu" = "dms ipc call spotlight toggle";
		"$screenshotUtil" = "grimblast -f save area - | swappy -f -";
		"$lock" = "dms ipc call lock lock";
		"$overview" = "dms ipc call hypr toggleOverview";

		bind = [
			"$mainMod, Q, exec, $terminal"
			"$mainMod, C, killactive"
			"$mainMod, E, exec, $fileManager"
			"$mainMod, V, togglefloating"
			"$mainMod, SPACE, exec, $menu"
			"$mainMod, T, togglesplit"
			"$mainMod ALT, L, exec, $lock"
			", Print, exec, $screenshotUtil"
			"$mainMod, TAB, exec, $overview"

			"$mainMod, S, togglespecialworkspace, magic"
			"$mainMod SHIFT, S, movetoworkspace, special:magic"


			"$mainMod, $left, movefocus, l"
			"$mainMod, $right, movefocus, r"
			"$mainMod, $up, movefocus, u"
			"$mainMod, $down, movefocus, d"

			# Move windows
			"$mainMod SHIFT, N, movewindow, l"
			"$mainMod SHIFT, I, movewindow, r"
			"$mainMod SHIFT, U, movewindow, u"
			"$mainMod SHIFT, comma, movewindow, d"
		]
		++ (
			# workspaces
			# binds $mod + [shift +] {1..9} to [move to] workspace {1..9}
			builtins.concatLists (
				builtins.genList (i:
					let ws = i + 1;
					in [
						"$mainMod, code:1${toString i}, workspace, ${toString ws}"
						"$mainMod SHIFT, code:1${toString i}, movetoworkspace, ${toString ws}"
					]
				)
			9)
		);
		# Mouse binds
		bindm = [
			"$mainMod, mouse:272, movewindow"
			"$mainMod, mouse:273, resizewindow"
		];
		# Repeating binds when held
		binde = [
			# Resize windows
			"$mainMod CTRL, $left, resizeactive, -50 0" # Right side of the window left
			"$mainMod CTRL, $right, resizeactive, 50 0"  # Right side of the window right
			"$mainMod CTRL, $up, resizeactive, 0 -50" # Bottom of the window up
			"$mainMod CTRL, $down, resizeactive, 0 50"  # Bottom of the window down
			# Move floating windows
			"$mainMod ALT, $left, moveactive, -50 0"
			"$mainMod ALT, $right, moveactive, 50 0"
			"$mainMod ALT, $up, moveactive, 0 -50"
			"$mainMod ALT, $down, moveactive, 0 50"
		];

  };
}
