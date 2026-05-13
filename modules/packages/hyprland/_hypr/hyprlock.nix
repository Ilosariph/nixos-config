{ config, osConfig, ... }:
let
  mainMonitor = osConfig.dotfiles.windowManager.mainMonitor;
  s = config.lib.stylix.colors;
in {
  programs.hyprlock.enable = true;

  programs.hyprlock.settings = {
    "$base"        = "rgb(${s.base00})";
    "$accent"      = "rgb(${s.base0E})";
    "$accentAlpha" = s.base0E;
    "$surface0"    = "rgb(${s.base01})";
    "$text"        = "rgb(${s.base05})";
    "$textAlpha"   = s.base05;
    "$red"         = "rgb(${s.base08})";
    "$yellow"      = "rgb(${s.base0A})";
    "$font"        = "JetBrainsMono Nerd Font";

    general = {
      "disable_loading_bar" = true;
      "hide_cursor" = true;
    };

    background = {
      "monitor" = "";
      "path" = "screenshot";
      "blur_passes" = 3;
      "color" = "$base";
    };

    label = [
      {
        "monitor" = mainMonitor;
        "text" = "cmd[update:30000] echo \"$(date +\"%R\")\"";
        "color" = "$text";
        "font_size" = 90;
        "font_family" = "$font";
        "position" = "-30, 0";
        "halign" = "right";
        "valign" = "top";
      }
      {
        "monitor" = mainMonitor;
        "text" = "cmd[update:43200000] echo \"$(date +\"%A, %d %B %Y\")\"";
        "color" = "$text";
        "font_size" = 25;
        "font_family" = "$font";
        "position" = "-30, -150";
        "halign" = "right";
        "valign" = "top";
      }
    ];

    input-field = {
      "monitor" = mainMonitor;
      "size" = "300, 60";
      "outline_thickness" = 4;
      "dots_size" = 0.2;
      "dots_spacing" = 0.2;
      "dots_center" = true;
      "outer_color" = "$accent";
      "inner_color" = "$surface0";
      "font_color" = "$text";
      "fade_on_empty" = false;
      "placeholder_text" = "<span foreground=\"##$accentAlpha\">󰌾  Logged in as <span foreground=\"##$accentAlpha\">$USER</span></span>";
      "hide_input" = false;
      "check_color" = "$accent";
      "fail_color" = "$red";
      "fail_text" = "<i>$FAIL <b>($ATTEMPTS)</b></i>";
      "capslock_color" = "$yellow";
      "position" = "0, -35";
      "halign" = "center";
      "valign" = "center";
    };
  };
}
