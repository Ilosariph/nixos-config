{ ... }: {
  # finix counterpart of modules/packages/umbriel/umbriel.nix. Shares the
  # config.toml settings (modules/packages/umbriel/_settings.nix); only the
  # autostart list differs: finit has no user services, so everything systemd
  # user units start on NixOS (pipewire, udiskie, ...) is launched by Umbriel
  # itself. Other aspects add theirs through windowManager.settings.execOnce
  # (noctalia, openrazer-daemon).
  flake.finixModules.umbriel = { config, pkgs, lib, modules, ... }:
    let
      dotfiles = config.dotfiles;
      user = dotfiles.user.name;
      isUmbrielPrimary = dotfiles.desktop.enable && dotfiles.windowManager.type == "umbriel";
      tomlFormat = pkgs.formats.toml { };

      autostart =
        [ "dbus-update-activation-environment WAYLAND_DISPLAY DISPLAY XDG_CURRENT_DESKTOP XDG_SESSION_TYPE" ]
        ++ lib.optionals dotfiles.desktop.enable [ "start-audio-daemons" ]
        ++ lib.optionals dotfiles.programs._1password.enable [ "1password --silent" ]
        ++ lib.optionals dotfiles.programs.udiskie.enable [ "udiskie" ]
        ++ dotfiles.windowManager.settings.execOnce;

      settings = lib.recursiveUpdate
        (import ../../packages/umbriel/_settings.nix {
          inherit lib autostart;
          osConfig = config;
        })
        {
          # home-manager home.sessionVariables / systemd.user.sessionVariables
          environment = {
            QT_QPA_PLATFORM = "wayland";
            QT_WAYLAND_DISABLE_WINDOWDECORATION = "1";
            GDK_BACKEND = "wayland";
            GSK_RENDERER = "ngl";
          };
        };

      gnomeKeyringPam = "${pkgs.gnome-keyring}/lib/security/pam_gnome_keyring.so";
    in {
      imports = with modules; [ umbriel gnome-keyring ];

      config = lib.mkIf isUmbrielPrimary {
        # Installs umbriel and its wayland session (dbus-run-session wrapper)
        programs.umbriel.enable = true;
        programs.gnome-keyring.enable = true;

        xdg.portal = {
          enable = true;
          portals = [ pkgs.xdg-desktop-portal-gtk pkgs.xdg-desktop-portal-umbriel ];
        };
        environment.etc."xdg/xdg-desktop-portal/umbriel-portals.conf".text = ''
          [preferred]
          default=umbriel;gtk
        '';

        # Unlock the login keyring with the greetd password
        security.pam.services.greetd.text = lib.mkMerge [
          (lib.mkBefore ''
            auth optional pam_unix.so likeauth nullok
            auth optional ${gnomeKeyringPam}
          '')
          (lib.mkAfter ''
            session optional ${gnomeKeyringPam} auto_start
          '')
        ];

        security.pam.services.swaylock.text = ''
          auth sufficient pam_unix.so likeauth try_first_pass
          auth required pam_deny.so
          account required pam_unix.so
        '';

        environment.systemPackages = with pkgs; [
          swaylock
          swayidle
          xwayland
          grim
          slurp
          dbus
        ];

        hjem.users.${user}.xdg.config.files."umbriel/config.toml".source =
          tomlFormat.generate "umbriel-config.toml" settings;
      };
    };
}
