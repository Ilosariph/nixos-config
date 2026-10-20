{ inputs, ... }: {
  flake.nixosModules.noctalia = { config, lib, ... }:
    lib.mkIf (config.dotfiles.desktop.enable && config.dotfiles.windowManager.statusbar == "noctalia") {
      home-manager.sharedModules = [ inputs.noctalia-shell.homeModules.default ];
      home-manager.users.${config.dotfiles.user.name} = { lib, pkgs, config, osConfig, ... }:
        let
          randomWallpaperScript = pkgs.writeShellScript "noctalia-random-wallpaper" ''
            set -eu
            for _ in $(seq 1 30); do
              if ${inputs.noctalia-shell.packages.${pkgs.stdenv.hostPlatform.system}.default}/bin/noctalia msg wallpaper-random >/dev/null 2>&1; then
                exit 0
              fi
              sleep 1
            done
            exit 1
          '';
        in {
          programs.noctalia = {
            enable = true;
            systemd.enable = true;
            settings = import ./_settings.nix { inherit lib pkgs osConfig; };
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
