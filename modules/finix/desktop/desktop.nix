{ ... }: {
  # finix counterpart of modules/packages/desktop/desktop.nix.
  # Not ported: printing (no CUPS module on finix), declarative flatpak apps
  # (nix-flatpak is a home-manager module; install them with `flatpak install`),
  # libvirt (no finix module), the NixOS VM variant.
  flake.finixModules.desktop = { config, pkgs, lib, modules, ... }:
    let
      user = config.dotfiles.user.name;
      isNoctalia = config.dotfiles.windowManager.statusbar == "noctalia";

      gtkTheme = pkgs.colloid-gtk-theme.override {
        themeVariants = [ "default" ];
        colorVariants = [ "dark" ];
        tweaks = [ "dracula" ];
      };
      gtkThemeName = "Colloid-Dark-Dracula";
      cursorName = "material_light_cursors";
      cursorSize = 20;

      gtkSettings = ''
        [Settings]
        gtk-theme-name=${gtkThemeName}
        gtk-cursor-theme-name=${cursorName}
        gtk-cursor-theme-size=${toString cursorSize}
        gtk-application-prefer-dark-theme=1
      '';

      # 1Password GUI with the polkit policy owner baked in (NixOS:
      # programs._1password-gui.polkitPolicyOwners)
      onePasswordGui = pkgs._1password-gui.override {
        polkitPolicyOwners = [ user ];
      };
    in {
      imports = with modules; [
        pipewire
        wireplumber
        rtkit
        udisks2
        gvfs
        dconf
        flatpak
        upower
        power-profiles-daemon
        fwupd
      ];

      config = lib.mkIf config.dotfiles.desktop.enable {
        programs.pipewire = {
          enable = true;
          alsa.enable = true;
          alsa.support32Bit = true;
        };
        programs.wireplumber.enable = true;

        services.rtkit.enable = true;
        services.udisks2.enable = true;
        services.gvfs.enable = true;
        services.flatpak.enable = true;
        programs.dconf.enable = true;

        # noctalia's battery/power-profile widgets
        services.power-profiles-daemon.enable = lib.mkIf isNoctalia true;
        services.upower.enable = lib.mkIf isNoctalia true;

        hardware.graphics.enable = true;

        xdg.portal = {
          enable = true;
          portals = [ pkgs.xdg-desktop-portal-gtk ];
        };

        # 1Password: setgid helpers as in the NixOS programs._1password(-gui)
        # modules (browser integration + CLI talk to the desktop app)
        users.groups.onepassword = { };
        users.groups.onepassword-cli = { };
        security.wrappers = {
          "1Password-BrowserSupport" = {
            source = "${onePasswordGui}/share/1password/1Password-BrowserSupport";
            owner = "root";
            group = "onepassword";
            setuid = false;
            setgid = true;
          };
          op = {
            source = "${pkgs._1password-cli}/bin/op";
            owner = "root";
            group = "onepassword-cli";
            setuid = false;
            setgid = true;
          };
        };
        services.dbus.packages = [ onePasswordGui ];

        environment.systemPackages = with pkgs; [
          onePasswordGui
          firefox
          gcc

          lm_sensors

          libsecret
          pulseaudio
          pavucontrol
          audacity

          proton-vpn

          spice-gtk

          xdg-utils
          gsettings-desktop-schemas
          gnome-themes-extra
          glib
          desktop-file-utils
          libnotify
          material-cursors
          blueman
          networkmanagerapplet
          seahorse

          kdePackages.dolphin
          filezilla
          fsearch

          chromium

          vlc
          jellyfin-mpv-shim
          qview

          gimp
          libreoffice
          obsidian
          jetbrains.pycharm

          github-desktop

          weechat

          playerctl
          brightnessctl
          clipse
          wl-clip-persist
          wl-clipboard

          gtkTheme
          adwaita-qt
          adwaita-qt6
        ] ++ lib.optionals (pkgs.stdenv.hostPlatform.system == "x86_64-linux") [
          spotify
          discord
          protonmail-desktop
        ];

        fonts.fontconfig.enable = true;
        fonts.packages = with pkgs; [
          nerd-fonts.jetbrains-mono
          nerd-fonts.fira-code
          jetbrains-mono
        ];

        # libadwaita / portals read color-scheme from dconf
        programs.dconf.profiles.user.databases = [
          {
            settings."org/gnome/desktop/interface" = {
              color-scheme = "prefer-dark";
              gtk-theme = gtkThemeName;
              cursor-theme = cursorName;
              cursor-size = lib.gvariant.mkInt32 cursorSize;
            };
          }
        ];

        # Session variables (home-manager home.sessionVariables) go through
        # pam_env so the greetd session and everything it spawns get them.
        security.pam.environment = lib.mapAttrs (_: v: { default = v; }) {
          XDG_THEME_MODE = "dark";
          DEFAULT_BROWSER = "${pkgs.firefox}/bin/firefox";
          BROWSER = "firefox";
          GTK_USE_PORTAL = "1";
          GTK_THEME = gtkThemeName;
          XCURSOR_THEME = cursorName;
          XCURSOR_SIZE = "35";
          NIXOS_OZONE_WL = "1";
          QT_QPA_PLATFORMTHEME = "adwaita-dark";
        };

        hjem.users.${user} = {
          # jellyfin-mpv-shim: screenshot filename template + `e` bind. The
          # screenshot dir lives in its own conf.json (patched by
          # home-manager activation on NixOS; set it once in the app here).
          xdg.config.files = {
            "jellyfin-mpv-shim/mpv.conf".text = ''
              screenshot-template=mpv-shot-%tY-%tm-%td-%tHh%tMm%tSs-%f
            '';
            "jellyfin-mpv-shim/input.conf".text = ''
              e screenshot
            '';
            "gtk-3.0/settings.ini".text = gtkSettings;
            "gtk-4.0/settings.ini".text = gtkSettings;
          };

          files.".gtkrc-2.0".text = ''
            gtk-theme-name="${gtkThemeName}"
            gtk-cursor-theme-name="${cursorName}"
            gtk-cursor-theme-size=${toString cursorSize}
          '';

          xdg.data.files."icons/default/index.theme".text = ''
            [Icon Theme]
            Name=Default
            Comment=Default Cursor Theme
            Inherits=${cursorName}
          '';

          xdg.mime-apps.default-applications =
            let
              browser = [ "firefox.desktop" ];
              imgViewer = [ "com.interversehq.qView.desktop" ];
              vidViewer = [ "mpv.desktop" ];
              fileManager = [ "org.kde.dolphin.desktop" ];
              audioPlayer = [ "mpv.desktop" ];
              textEditor = [ "zed.desktop" ];
              archiveManager = [ "org.kde.dolphin.desktop" ];
              officeSuite = [ "libreoffice-writer.desktop" ];
              spreadsheet = [ "libreoffice-calc.desktop" ];
              presentation = [ "libreoffice-impress.desktop" ];
            in {
              "image/png" = imgViewer;
              "image/webp" = imgViewer;
              "image/jpeg" = imgViewer;
              "image/gif" = imgViewer;
              "image/svg+xml" = imgViewer;
              "image/avif" = imgViewer;
              "image/bmp" = imgViewer;
              "image/tiff" = imgViewer;
              "image/x-icon" = imgViewer;

              "inode/directory" = fileManager;

              "video/avi" = vidViewer;
              "video/flv" = vidViewer;
              "video/x-flv" = vidViewer;
              "video/mp4" = vidViewer;
              "video/mpeg" = vidViewer;
              "video/webm" = vidViewer;
              "video/vnd.avi" = vidViewer;
              "video/x-msvideo" = vidViewer;
              "video/x-matroska" = vidViewer;
              "video/matroska" = vidViewer;
              "video/matroska-3d" = vidViewer;
              "video/quicktime" = vidViewer;
              "video/ogg" = vidViewer;
              "video/3gpp" = vidViewer;

              "audio/mpeg" = audioPlayer;
              "audio/flac" = audioPlayer;
              "audio/ogg" = audioPlayer;
              "audio/wav" = audioPlayer;
              "audio/x-wav" = audioPlayer;
              "audio/aac" = audioPlayer;
              "audio/mp4" = audioPlayer;
              "audio/x-m4a" = audioPlayer;
              "audio/webm" = audioPlayer;

              "application/pdf" = browser;
              "text/plain" = textEditor;
              "text/markdown" = textEditor;
              "application/vnd.openxmlformats-officedocument.wordprocessingml.document" = officeSuite;
              "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet" = spreadsheet;
              "application/vnd.openxmlformats-officedocument.presentationml.presentation" = presentation;
              "application/msword" = officeSuite;
              "application/vnd.ms-excel" = spreadsheet;
              "application/vnd.ms-powerpoint" = presentation;
              "application/vnd.oasis.opendocument.text" = officeSuite;
              "application/vnd.oasis.opendocument.spreadsheet" = spreadsheet;
              "application/vnd.oasis.opendocument.presentation" = presentation;

              "application/zip" = archiveManager;
              "application/x-tar" = archiveManager;
              "application/gzip" = archiveManager;
              "application/x-bzip2" = archiveManager;
              "application/x-7z-compressed" = archiveManager;
              "application/vnd.rar" = archiveManager;
              "application/x-xz" = archiveManager;

              "text/html" = browser;
              "x-scheme-handler/http" = browser;
              "x-scheme-handler/https" = browser;
              "x-scheme-handler/about" = browser;
              "x-scheme-handler/unknown" = browser;
              "x-scheme-handler/ftp" = [ "filezilla.desktop" ];
            };
        };
      };
    };
}
