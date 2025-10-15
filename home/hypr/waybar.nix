{
  programs.waybar.settings.mainBar = {
	"layer" = "top";
	"modules-left" = [ "clock" "hyprland/workspaces" ];
	"modules-center" = [ "hyprland/window" ];
	"modules-right" = [ "custom/waybar-mpris" "cpu" "memory" "temperature" "pulseaudio" ];
	"hyprland/workspaces" = {
	  "sort" = "number";
      "format" = "{name}: {icon}";
      "on-click" = "activate";
      "format-icons" = {
		"active" = " ";
		"default" = " ";
      };
	  "hyprland/window" = {
		"format" = "{title}";
	  };
    };
	"custom/waybar-mpris" = {
      "return-type" = "json";
      "exec" = "waybar-mpris --position --autofocus --order ARTIST:TITLE";
      "escape" = true;
  	};
    "clock" = {
        "format" = "{:%H:%M %a %b %d}";
        "tooltip" = false;
    };
    "cpu" = {
        "format" = "  {usage}%";
        "tooltip" = false;
    };
    "memory" = {
        "format" = " {}%";
        "tooltip" = false;
    };
    "temperature" = {
        # // "thermal-zone" = 2;
        "hwmon-path" = "/dev/cpu_temp";
        "critical-threshold" = 80;
        # // "format-critical" = "{temperatureC}°C {icon}";
        "format" = "{icon} {temperatureC}°C";
        "format-icons" = ["" "" "" "" ""];
        "tooltip" = false;
    };
    "pulseaudio" = {
        # // "scroll-step" = 1; // %, can be a float
        "format" = "{icon}   {volume}% {format_source}";
        "format-bluetooth" = "{volume}% {icon} {format_source}";
        "format-bluetooth-muted" = " {icon} {format_source}";
        "format-muted" = " {format_source}";
        "format-source" = " {volume}%";
        "format-source-muted" = "";
        "format-icons" = {
            "headphone" = "";
            "hands-free" = "";
            "headset" = "";
            "phone" = "";
            "portable" = "";
            "car" = "";
            "default" = ["" "" ""];
            "tooltip" = false;
        };
        "on-click" = "pavucontrol";
    };
  };

  programs.waybar.style = ''
	
@keyframes blink-warning {
    70% {
        color: @light;
    }

    to {
        color: @light;
        background-color: @warning;
    }
}

@keyframes blink-critical {
    70% {
      color: @light;
    }

    to {
        color: @light;
        background-color: @critical;
    }
}


/* -----------------------------------------------------------------------------
 * Styles
 * -------------------------------------------------------------------------- */

/* COLORS */

/* Nord */
@define-color bg #353C4A;
@define-color light #cdd6f4;
@define-color dark #2e3440;
@define-color warning #ebcb8b;
@define-color critical #f38ba8;
@define-color mode #1e1e2e;
@define-color workspaces #1e1e2e;
@define-color workspacesfocused #1e1e2e;
@define-color tray @workspacesfocused;
@define-color sound #1e1e2e;
@define-color network #1e1e2e;
@define-color memory #1e1e2e;
@define-color cpu #1e1e2e;
@define-color temp #1e1e2e;
@define-color layout #1e1e2e;
@define-color battery #1e1e2e;
@define-color date #1e1e2e;
@define-color time #3A4253;
@define-color backlight #1e1e2e;
@define-color apple #1e1e2e;




/* Reset all styles */
* {
    border: none;
    border-radius: 0;
    min-height: 0;
    margin: 0;
    padding: 0;
}

/* The whole bar */
#waybar {
    background: rgba(0,0,0,0);
    color: @light;
    /*font-family: "Noto Sans", "Font Awesome 6 Free";*/
	font-family: "JetBrains Mono", "FiraCode Nerd Font Mono";
    font-size: 12px;
    font-weight: bold;
}

/* Each module */
#battery,
#cpu,
#custom-layout,
#memory,
#mode,
#network,
#pulseaudio,
#temperature,
#custom-alsa,
#tray,
#backlight {
    padding-left: 10px;
    padding-right: 10px;
    margin-left: 5px;
    margin-top: 4px;
    padding-top: 5px;
    padding-bottom: 5px;
    margin-bottom: 3px;
}

#clock {
    padding-left: 10px;
    padding-right: 10px;
    margin-right: 5px;
    margin-top: 4px;
    padding-top: 5px;
    padding-bottom: 5px;
    margin-bottom: 3px;
}

#custom-apple {
    padding-left: 8px;
    padding-right: 8px;
    margin-right: 5px;
    margin-top: 4px;
    padding-top: 2px;
    padding-bottom: 2px;
    margin-bottom: 3px;
}
/* Each module that should blink */
#mode,
#memory,
#temperature,
#battery {
    animation-timing-function: linear;
    animation-iteration-count: infinite;
    animation-direction: alternate;
}

/* Each critical module */
#memory.critical,
#cpu.critical,
#temperature.critical,
#battery.critical {
    color: @critical;
}

/* Each critical that should blink */
#mode,
#memory.critical,
#temperature.critical,
#battery.critical.discharging {
    animation-name: blink-critical;
    animation-duration: 2s;
}

/* Each warning */
#network.disconnected,
#memory.warning,
#cpu.warning,
#temperature.warning,
#battery.warning {
    color: @warning;
}


/* Each warning that should blink */
#battery.warning.discharging {
    animation-name: blink-warning;
    animation-duration: 3s;
}

/* And now modules themselves in their respective order */

#mode { /* Shown current Sway mode (resize etc.) */
	color: @light;
	background: @mode;
}

/* Workspaces stuff */

/* #workspaces {
    border-radius: 8px;
} */


#workspaces button {
	font-weight: bold;
	padding-left: 5px;
	padding-right: 5px;
	color: @light;
	background: @workspaces;
    border-radius: 8px;
    margin-top: 4px;
    padding-top: 5px;
    padding-bottom: 5px;
    margin-bottom: 3px;
    margin-right: 1px;

}

#workspaces button.active {
    color: #f9e2af;
}

#workspaces button.urgent {
    color: #f38ba8;
}

#window {
	margin-right: 40px;
	margin-left: 40px;
}

#custom-alsa {
	background: @sound;
    border-radius: 8px;

}

#network {
    background: @network;
    border-radius: 8px;
}

#memory {
    background: @memory;
    border-radius: 8px;
}

#cpu {
    background: @cpu;
    border-radius: 8px;
}

#temperature {
    background: @temp;
    border-radius: 8px;
}

#custom-layout {
    background: @layout;
    border-radius: 8px;
}

#battery {
    background: @battery;
    border-radius: 8px;
    border-top-right-radius: 16px;
    margin-right: 5px;

    /* border-top-left-radius: 10px;
    border-bottom-left-radius: 10px; */
}

#backlight {
	background: @backlight;
    border-radius: 8px;
}

#clock {
    background: @date;
    border-radius: 8px;
    /* border-top-right-radius: 10px;
    border-bottom-right-radius: 10px; */
}


#pulseaudio {
    background: @sound;
    border-radius: 8px;
}


#tray {
	background: @tray;
    border-radius: 8px;
}

#custom-apple {
    font-size: 17px;
    background: @apple;
    border-radius: 8px;
    border-top-left-radius: 16px;
    margin-left: 5px;
    padding-left: 14px;
    padding-right: 14px;
}

#custom-notch {
    margin-left: 100px;
    margin-right: 100px;
    padding-left: 14px;
    padding-right: 14px;
}
  '';
}
