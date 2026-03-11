{ pkgs, config, ... }:
let
  wallpaperPath = config.home.sessionVariables.WALLPAPER_DIR;
  randomWallpaperScript = pkgs.writeShellScriptBin "random-wallpaper" (builtins.readFile ./random_background.sh);
  wallpaperDir = ./wallpapers;
  wallpaperFiles = builtins.attrNames (builtins.readDir wallpaperDir);
  wallpaperPaths = map (name: "${wallpaperPath}/${name}") wallpaperFiles;
in {
  home.packages = [ randomWallpaperScript ];
  wayland.windowManager.hyprland.settings.exec-once = [
		"${randomWallpaperScript}/bin/random-wallpaper ${wallpaperPath} > /home/simon/random-wallpaper-script.txt 2>&1"
	];
  services.hyprpaper = {
		enable = true;
		settings = {
			preload = wallpaperPaths;
			wallpaper = [ ",${wallpaperPath}/shaded.png" ];
		};
  };
}
