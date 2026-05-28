{ ... }: {
  flake.nixosModules.greetd = { config, lib, pkgs, ... }:
    lib.mkIf (config.dotfiles.desktop.enable && config.dotfiles.windowManager.displayManager == "greetd") {
      environment.pathsToLink = [ "/share/wayland-sessions" ];

      services.greetd = {
        enable = true;
        settings.default_session = {
          command = "${pkgs.tuigreet}/bin/tuigreet --time --remember --sessions /run/current-system/sw/share/wayland-sessions";
          user = "greeter";
        };
      };
    };
}
