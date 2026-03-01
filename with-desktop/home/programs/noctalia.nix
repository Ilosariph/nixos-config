{ lib, config, osConfig, ... }:
let
  wallpaperPath = config.home.sessionVariables.WALLPAPER_DIR;
  wallpaperDir = ../../hyprland/hypr/hyprpaper/wallpapers;
  wallpaperFiles = builtins.attrNames (builtins.readDir wallpaperDir);
  wallpaperPaths = map (name: "${wallpaperPath}/${name}") wallpaperFiles;
  defaultWallpaper = if wallpaperPaths != [] then builtins.head wallpaperPaths else "";
in {
  config = lib.mkIf (osConfig.dotfiles.hyprland.statusbar == "noctalia") {
    programs.noctalia-shell.enable = true;

    home.file.".cache/noctalia/wallpapers.json" = {
      text = builtins.toJSON {
        defaultWallpaper = defaultWallpaper;
        wallpapers = wallpaperPaths;
      };
    };
  };
}
