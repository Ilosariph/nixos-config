{ pkgs, config, ... }:
let
  wallpaperPath = config.home.sessionVariables.WALLPAPER_DIR;
  randomWallpaperScript = pkgs.writeShellScriptBin "random-wallpaper" (builtins.readFile ./random_background.sh);
in {
  home.packages = [ randomWallpaperScript ];
  wayland.windowManager.hyprland.settings.exec-once = [
		"${randomWallpaperScript}/bin/random-wallpaper ${wallpaperPath} > /home/simon/random-wallpaper-script.txt 2>&1"
	];
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
