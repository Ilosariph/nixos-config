{ inputs, ... }: {
  flake.nixosModules.noctalia = { config, lib, pkgs, ... }:
    lib.mkIf (config.dotfiles.desktop.enable && config.dotfiles.windowManager.statusbar == "noctalia") {
      home-manager.sharedModules = [ inputs.noctalia-shell.homeModules.default ];
      home-manager.users.${config.dotfiles.user.name} = { lib, config, osConfig, ... }:
        let
          wallpaperDir = ../hyprland/_hypr/hyprpaper/wallpapers;
          wallpaperFiles = builtins.attrNames (builtins.readDir wallpaperDir);
          wallpaperPaths = map (name: "${wallpaperDir}/${name}") wallpaperFiles;
          defaultWallpaper = if wallpaperPaths != [] then builtins.head wallpaperPaths else "";
          obsidianSearch = osConfig.dotfiles.programs.noctaliaObsidianSearch;
        in lib.mkMerge [
          {
            programs.noctalia-shell.enable = true;

            home.file.".cache/noctalia/wallpapers.json" = {
              text = builtins.toJSON {
                inherit defaultWallpaper;
                wallpapers = wallpaperPaths;
              };
            };
          }

          (lib.mkIf obsidianSearch.enable {
            home.packages = with pkgs; [ fd ripgrep ];

            xdg.configFile."noctalia/plugins/obsidian-notes/LauncherProvider.qml".source = ./obsidian-notes/LauncherProvider.qml;
            xdg.configFile."noctalia/plugins/obsidian-notes/Main.qml".source = ./obsidian-notes/Main.qml;
            xdg.configFile."noctalia/plugins/obsidian-notes/manifest.json".source = ./obsidian-notes/manifest.json;

            programs.noctalia-shell.plugins = {
              states."obsidian-notes" = {
                enabled = true;
                sourceUrl = "local";
              };
              version = 2;
            };

            programs.noctalia-shell.pluginSettings."obsidian-notes" = {
              vaultPath = obsidianSearch.vaultPath;
              downrankedFolders = obsidianSearch.downrankedFolders;
              maxResults = 50;
            };
          })
        ];
    };
}
