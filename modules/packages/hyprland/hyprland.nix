{ ... }: {
  flake.nixosModules.hyprland = { config, pkgs, lib, ... }:
    let
      isDesktop = config.dotfiles.desktop.enable;
      isHyprlandPrimary = isDesktop && config.dotfiles.windowManager.type == "hyprland";
      isWaybar = config.dotfiles.windowManager.statusbar == "waybar";
    in {
      # Always install hyprland on desktop so it appears in greetd session list
      programs.hyprland = lib.mkIf isDesktop { enable = true; };

      systemd.user.services.xdg-desktop-portal-hyprland = lib.mkIf isDesktop {
        wantedBy = [ "hyprland-session.target" ];
      };
      systemd.user.services.xdg-desktop-portal-gtk = lib.mkIf isDesktop {
        wantedBy = [ "hyprland-session.target" ];
      };

      nix.settings = lib.mkIf isDesktop {
        extra-substituters = [ "https://hyprland.cachix.org" ];
        extra-trusted-public-keys = [ "hyprland.cachix.org-1:a7pgxzMz7+chwVL3/pzj6jIBMioiJM7ypFP8PwtkuGc=" ];
      };

      services.gnome.gnome-keyring.enable = lib.mkIf isDesktop true;
      security.pam.services.hyprland = lib.mkIf isDesktop { enableGnomeKeyring = true; };
      security.pam.services.login = lib.mkIf isDesktop { enableGnomeKeyring = true; };

      # Hyprland-specific home config (idle, lock, wallpaper) only when hyprland is primary WM
      home-manager.sharedModules = lib.optionals isHyprlandPrimary ([
        ./_hypr/hyprland.nix
        ./_hypr/hypridle.nix
        ./_hypr/hyprlock.nix
      ] ++ lib.optionals isWaybar [
        ./_hypr/hyprpaper/hyprpaper.nix
      ]);

      home-manager.users.${config.dotfiles.user.name} = lib.mkIf isDesktop {
        home.sessionVariables = {
          QT_QPA_PLATFORM = "wayland";
          QT_WAYLAND_DISABLE_WINDOWDECORATION = "1";
        };

        xdg.portal = {
          extraPortals = with pkgs; [
            xdg-desktop-portal-hyprland
          ];
        };

        services.hyprpolkitagent.enable = true;

        home.pointerCursor = {
          hyprcursor.enable = true;
          hyprcursor.size = 35;
        };

        home.packages = lib.optionals isWaybar (with pkgs; [
          hyprpaper
        ]);
      };
    };
}
