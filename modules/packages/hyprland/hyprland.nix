{ ... }: {
  flake.nixosModules.hyprland = { config, pkgs, lib, ... }:
    let
      isHyprland = config.dotfiles.desktop.enable && config.dotfiles.windowManager.type == "hyprland";
      isWaybar = config.dotfiles.windowManager.statusbar == "waybar";
      wallpaperDir = pkgs.stdenv.mkDerivation {
        name = "wallpapers";
        src = ./_hypr/hyprpaper/wallpapers;
        installPhase = "mkdir -p $out && cp -r $src/* $out";
      };
    in {
      # System config
      programs.hyprland = lib.mkIf isHyprland { enable = true; };

      environment.sessionVariables = lib.mkIf isHyprland {
        XDG_CURRENT_DESKTOP = "Hyprland";
        XDG_SESSION_DESKTOP = "Hyprland";
        XDG_SESSION_TYPE = "wayland";
      };

      systemd.user.services.xdg-desktop-portal-hyprland = lib.mkIf isHyprland {
        wantedBy = [ "hyprland-session.target" ];
      };
      systemd.user.services.xdg-desktop-portal-gtk = lib.mkIf isHyprland {
        wantedBy = [ "hyprland-session.target" ];
      };

      nix.settings = lib.mkIf isHyprland {
        extra-substituters = [ "https://hyprland.cachix.org" ];
        extra-trusted-public-keys = [ "hyprland.cachix.org-1:a7pgxzMz7+chwVL3/pzj6jIBMioiJM7ypFP8PwtkuGc=" ];
      };

      services.gnome.gnome-keyring.enable = lib.mkIf isHyprland true;
      security.pam.services.hyprland = lib.mkIf isHyprland { enableGnomeKeyring = true; };
      security.pam.services.login = lib.mkIf isHyprland { enableGnomeKeyring = true; };

      # Add hyprland sub-modules via sharedModules (supports imports properly)
      home-manager.sharedModules = lib.optionals isHyprland ([
        ./_hypr/hyprland.nix
        ./_hypr/hypridle.nix
        ./_hypr/hyprlock.nix
      ] ++ lib.optionals isWaybar [
        ./_hypr/hyprpaper/hyprpaper.nix
      ]);

      # Home-manager config via option (not imports)
      home-manager.users.${config.dotfiles.user.name} = lib.mkIf isHyprland {
        home.sessionVariables = {
          QT_QPA_PLATFORM = "wayland";
          QT_WAYLAND_DISABLE_WINDOWDECORATION = "1";
          WALLPAPER_DIR = "${wallpaperDir}";
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
