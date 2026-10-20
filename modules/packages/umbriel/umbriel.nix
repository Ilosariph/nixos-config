{ ... }: {
  # Umbriel: Noctalia's wlroots compositor (scrolling/dwindle/master layouts).
  # Alternative to niri, selected with dotfiles.windowManager.type = "umbriel".
  # Config mirrors niri.nix as closely as Umbriel's actions allow.
  # Docs: https://docs.noctalia.dev/umbriel/
  flake.nixosModules.umbriel = { config, pkgs, lib, ... }:
    let
      isDesktop = config.dotfiles.desktop.enable;
      isUmbrielPrimary = isDesktop && config.dotfiles.windowManager.type == "umbriel";
    in {
      # Installs umbriel, registers the wayland session for greetd/tuigreet,
      # and adds xdg-desktop-portal-umbriel (screencast)
      programs.umbriel.enable = lib.mkIf isUmbrielPrimary true;

      # Umbriel starts Xwayland itself on demand (general.xwayland), it only
      # needs the binary on PATH
      programs.xwayland.enable = lib.mkIf isUmbrielPrimary true;

      xdg.portal = lib.mkIf isUmbrielPrimary {
        enable = true;
        extraPortals = [ pkgs.xdg-desktop-portal-gtk ];
        config.umbriel.default = [ "umbriel" "gtk" ];
      };

      security.polkit.enable = lib.mkIf isUmbrielPrimary true;
      services.gnome.gnome-keyring.enable = lib.mkIf isUmbrielPrimary true;
      security.pam.services.swaylock = lib.mkIf isUmbrielPrimary {};
      security.pam.services.login = lib.mkIf isUmbrielPrimary { enableGnomeKeyring = true; };

      environment.systemPackages = lib.optionals isUmbrielPrimary (with pkgs; [
        swaylock
        swayidle
      ]);

      # Home-manager config
      home-manager.users.${config.dotfiles.user.name} = { lib, pkgs, osConfig, ... }:
        let
          cfg = osConfig.dotfiles.windowManager.settings;
          statusbar = osConfig.dotfiles.windowManager.statusbar;
          tomlFormat = pkgs.formats.toml { };

          baseAutostart =
            # noctalia daemon is started by its systemd user service (programs.noctalia.systemd.enable)
            lib.optionals (statusbar == "waybar") [ "waybar" ]
            ++ lib.optionals osConfig.dotfiles.programs._1password.enable [ "1password --silent" ];

          settings = import ./_settings.nix {
            inherit lib osConfig;
            autostart = baseAutostart ++ cfg.execOnce;
          };
        in lib.mkIf isUmbrielPrimary {
          home.packages = with pkgs; [ grim slurp ];

          home.sessionVariables = {
            QT_QPA_PLATFORM = "wayland";
            QT_WAYLAND_DISABLE_WINDOWDECORATION = "1";
            GDK_BACKEND = "wayland";
            GSK_RENDERER = "ngl";
          };

          # Umbriel owns DISPLAY / XDG_CURRENT_DESKTOP / XDG_SESSION_TYPE itself
          systemd.user.sessionVariables = {
            GDK_BACKEND = "wayland";
            GSK_RENDERER = "ngl";
            NIXOS_OZONE_WL = "1";
          };

          xdg.configFile."umbriel/config.toml".source =
            tomlFormat.generate "umbriel-config.toml" settings;
        };
    };
}
