{ inputs, ... }: {
  flake.nixosModules.noctalia = { config, lib, ... }:
    lib.mkIf (config.dotfiles.desktop.enable && config.dotfiles.windowManager.statusbar == "noctalia") {
      home-manager.sharedModules = [ inputs.noctalia-shell.homeModules.default ];
      home-manager.users.${config.dotfiles.user.name} = { lib, pkgs, config, osConfig, ... }:
        let
          wallpaperStore = pkgs.runCommand "wallpapers" { } ''
            mkdir -p $out
            cp -r ${osConfig.dotfiles.wallpapers.directory}/. $out/
          '';
          baseSettings = builtins.fromJSON (builtins.readFile ./settings.json);
          randomWallpaperScript = pkgs.writeShellScript "noctalia-random-wallpaper" ''
            set -eu
            for _ in $(seq 1 30); do
              if ${inputs.noctalia-shell.packages.${pkgs.system}.default}/bin/noctalia-shell ipc call wallpaper random "" >/dev/null 2>&1; then
                exit 0
              fi
              sleep 1
            done
            exit 1
          '';
        in {
          programs.noctalia-shell = {
            enable = true;
            settings = lib.recursiveUpdate baseSettings {
              wallpaper.directory = "${wallpaperStore}";
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

          systemd.user.services.noctalia-random-wallpaper = {
            Unit = {
              Description = "Pick a random Noctalia wallpaper on session start";
              After = [ "graphical-session.target" ];
              PartOf = [ "graphical-session.target" ];
            };
            Service = {
              Type = "oneshot";
              ExecStart = "${randomWallpaperScript}";
            };
            Install.WantedBy = [ "graphical-session.target" ];
          };
        };
    };
}
