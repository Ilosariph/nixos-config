{ ... }: {
  flake.nixosModules.greetd = { config, lib, pkgs, ... }:
    let
      greeter = config.dotfiles.desktop.greeter;
      locale = config.dotfiles.locale;
    in
    lib.mkIf config.dotfiles.desktop.enable {
      environment.pathsToLink = [ "/share/wayland-sessions" ];

      services.greetd = {
        enable = true;
        settings.default_session = {
          command = lib.mkIf (greeter == "tuigreet")
            "${pkgs.tuigreet}/bin/tuigreet --time --remember --remember-session --sessions /run/current-system/sw/share/wayland-sessions";
          user = "greeter";
        };
      };

      # Graphical greeter; module sets greetd's command, enables accounts-daemon + polkit.
      services.displayManager.noctalia-greeter = lib.mkIf (greeter == "noctalia") {
        enable = true;
        # Lets the user push noctalia-shell appearance (wallpaper/palette) to the greeter without a password.
        passwordlessSyncUsers = [ config.dotfiles.user.name ];
        cursorTheme = {
          package = pkgs.material-cursors;
          name = "material_light_cursors";
        };
        settings = {
          user.default = config.dotfiles.user.name;
          cursor.size = 20;
          appearance.wallpaper = {
            path = "${config.dotfiles.wallpapers.greeter}";
            fill_mode = "crop";
          };
          # Pin to the main monitor; greeter disables other outputs (falls back to all if it's disconnected).
          output = lib.mkIf (config.dotfiles.windowManager.mainMonitor != "") {
            name = config.dotfiles.windowManager.mainMonitor;
          };
          # Custom ch-nodead-cflex only lives in the patched xkb dir; plain ch types the same password.
          keyboard = {
            layout = if locale.xkbLayout == "ch-nodead-cflex" then "ch" else locale.xkbLayout;
            variant = locale.xkbVariant;
          };
        };
      };
    };
}
