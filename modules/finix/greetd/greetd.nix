{ ... }: {
  flake.finixModules.greetd = { config, lib, pkgs, modules, ... }: {
    imports = [ modules.greetd ];

    config = lib.mkIf config.dotfiles.desktop.enable {
      environment.pathsToLink = [ "/share/wayland-sessions" ];

      services.greetd = {
        enable = true;
        settings.default_session = {
          command = "${pkgs.tuigreet}/bin/tuigreet --time --remember --remember-session --sessions /run/current-system/sw/share/wayland-sessions";
          user = "greeter";
        };
      };
    };
  };
}
