{
  programs.hyprlock.enable = true;

  programs.hyprlock.settings = {
    "$base" = "rgb(1e1e2e)";
    "$font" = "JetBrainsMono Nerd Font";
    "$accent" = "rgb(cba6f7)";
    "$accentAlpha" = "cba6f7";
    "$surface0" = "rgb(313244)";
    "$text" = "rgb(cdd6f4)";
    "$textAlpha" = "cdd6f4";
    "$red" = "rgb(f38ba8)";
    "$yellow" = "rgb(f9e2af)";

    general = {
      "disable_loading_bar" = true;
      "hide_cursor" = true;
    };
    
    background = {
      "monitor" = "";
      "path" = "screenshot";
      "blur_passes" = 2;
      "color" = "$base";
    };

    label = [
      {
        "monitor" = "";
        "text" = "cmd[update:30000] echo \"$(date +\"%R\")\"";
        "color" = "$base";
        "font_size" = 90;
        "font_family" = "$font";
        "position" = "-30, 0";
        "halign" = "right";
        "valign" = "top";
      }
      {
        "monitor" = "";
        "text" = "cmd[update:43200000] echo \"$(date +\"%A, %d %B %Y\")\"";
        "color" = "$base";
        "font_size" = 25;
        "font_family" = "$font";
        "position" = "-30, -150";
        "halign" = "right";
        "valign" = "top";
      }
    ];

    input-field = {
      "monitor" = "";
      "size" = "300, 60";
      "outline_thickness" = 4;
      "dots_size" = 0.2;
      "dots_spacing" = 0.2;
      "dots_center" = true;
      "outer_color" = "$accent";
      "inner_color" = "$surface0";
      "font_color" = "$text";
      "fade_on_empty" = false;
      "placeholder_text" = "<span foreground=\"##$textAlpha\">󰌾  Logged in as <span foreground=\"##$accentAlpha\">$USER</span></span>";
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
