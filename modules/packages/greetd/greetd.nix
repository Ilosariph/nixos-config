{ ... }: {
  flake.nixosModules.greetd = { config, lib, pkgs, ... }:
    lib.mkIf (config.dotfiles.desktop.enable && config.dotfiles.windowManager.displayManager == "greetd") {
      services.greetd = {
        enable = true;
        settings.default_session = {
          command =
            let
              wm = config.dotfiles.windowManager.type;
              cmd = if wm == "hyprland" then "start-hyprland" else "niri --session";
            in
            "${pkgs.tuigreet}/bin/tuigreet --time --remember --cmd ${cmd}";
          user = "greeter";
        };
      };
    };
}
