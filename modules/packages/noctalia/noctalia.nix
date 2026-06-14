{ inputs, ... }: {
  flake.nixosModules.noctalia = { config, lib, ... }:
    lib.mkIf (config.dotfiles.desktop.enable && config.dotfiles.windowManager.statusbar == "noctalia") {
      home-manager.sharedModules = [ inputs.noctalia-shell.homeModules.default ];
      home-manager.users.${config.dotfiles.user.name} = { lib, config, osConfig, ... }:
        let
          wallpaperDir = ../hyprland/_hypr/hyprpaper/wallpapers;
          wallpaperFiles = builtins.attrNames (builtins.readDir wallpaperDir);
          wallpaperPaths = map (name: "${wallpaperDir}/${name}") wallpaperFiles;
          defaultWallpaper = if wallpaperPaths != [] then builtins.head wallpaperPaths else "";
        in {
          programs.noctalia-shell = {
            enable = true;
            settings = (builtins.fromJSON (builtins.readFile ./settings.json)) // {
              plugins = {
                sources = [
                  {
                    enabled = true;
                    name = "Legacy V4 Plugins";
                    url = "https://github.com/noctalia-dev/legacy-v4-plugins";
                  }
                ];
                states = {
                  web-search = {
                    enabled = true;
                    sourceUrl = "https://github.com/noctalia-dev/legacy-v4-plugins";
                  };
                  keybind-cheatsheet = {
                    enabled = true;
                    sourceUrl = "https://github.com/noctalia-dev/legacy-v4-plugins";
                  };
                };
                version = 2;
              };
            };
          };

          home.file.".cache/noctalia/wallpapers.json" = {
            text = builtins.toJSON {
              inherit defaultWallpaper;
              wallpapers = wallpaperPaths;
            };
          };
        };
    };
}
