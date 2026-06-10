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
            home.file.".config/noctalia/plugins/obsidian-notes".source =
              ./obsidian-notes;

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
