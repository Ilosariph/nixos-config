{ config, ... }:
let
  wallpaperPath = config.home.sessionVariables.WALLPAPER_DIR;
in {
  services.hyprpaper = {
	enable = true;
	settings = {
	  wallpaper = [ ",${wallpaperPath}" ];
	};
  };
}
