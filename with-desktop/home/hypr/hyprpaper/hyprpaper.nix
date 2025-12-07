{ config, ... }:
let
  wallpaperPath = config.home.sessionVariables.WALLPAPER_DIR;
in {
  services.hyprpaper = {
	enable = true;
	settings = {
	  preload = [
		"${wallpaperPath}/shaded.png"
		"${wallpaperPath}/car-with-full-moon-background.png"
		"${wallpaperPath}/lofiwallpaper.png"
		"${wallpaperPath}/nice-blue-background.png"
	  ];
	  wallpaper = [ ",${wallpaperPath}/shaded.png" ];
	};
  };
}
