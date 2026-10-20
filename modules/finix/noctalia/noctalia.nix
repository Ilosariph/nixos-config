{ inputs, ... }: {
  # Noctalia through the finix community hjem module (config.toml only; the
  # daemon is started by Umbriel's autostart). Settings are shared with the
  # NixOS aspect (modules/packages/noctalia/_settings.nix).
  flake.finixModules.noctalia = { config, lib, pkgs, ... }:
    let
      noctalia = inputs.noctalia-shell.packages.${pkgs.stdenv.hostPlatform.system}.default;
      randomWallpaper = pkgs.writeShellScriptBin "noctalia-random-wallpaper" ''
        set -eu
        for _ in $(seq 1 30); do
          if ${noctalia}/bin/noctalia msg wallpaper-random >/dev/null 2>&1; then
            exit 0
          fi
          sleep 1
        done
        exit 1
      '';
    in lib.mkMerge [
      {
        # registered unconditionally: hjem's user submodule type is built from it
        hjem.extraModules = [ inputs.finix-community.hjemModules.noctalia ];
      }

      (lib.mkIf (config.dotfiles.desktop.enable && config.dotfiles.windowManager.statusbar == "noctalia") {
        environment.systemPackages = [ randomWallpaper ];

        # NixOS: noctalia + noctalia-random-wallpaper systemd user services
        dotfiles.windowManager.settings.execOnce = lib.mkBefore [
          "${noctalia}/bin/noctalia"
          "noctalia-random-wallpaper"
        ];

        hjem.users.${config.dotfiles.user.name}.programs.noctalia = {
          enable = true;
          package = noctalia;
          settings = import ../../packages/noctalia/_settings.nix {
            inherit lib pkgs;
            osConfig = config;
          };
        };
      })
    ];
}
