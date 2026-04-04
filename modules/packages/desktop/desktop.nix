{ inputs, ... }: {
  flake.nixosModules.desktop = { config, pkgs, lib, ... }:
    lib.mkIf config.dotfiles.desktop.enable {
      # Desktop system services
      services.printing.enable = true;

      services.pulseaudio.enable = false;
      security.rtkit.enable = true;
      services.pipewire = {
        enable = true;
        alsa.enable = true;
        alsa.support32Bit = true;
        pulse.enable = true;
      };

      services.xserver.enable = true;

      services.udisks2.enable = true;
      services.gvfs.enable = true;
      services.dbus.enable = true;

      xdg.portal.enable = true;

      programs.dconf.enable = true;

      programs.firefox.enable = true;

      # 1Password GUI (desktop only)
      programs._1password-gui = {
        enable = true;
        polkitPolicyOwners = [ config.dotfiles.user.name ];
      };

      hardware.graphics.enable = true;

      environment.systemPackages = with pkgs; [
        gcc

        polychromatic
        lm_sensors
        razergenie

        libsecret
        pulsemeeter
        pulseaudio
        pavucontrol
        qpwgraph

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

        grimblast
        hyprpicker
        playerctl
        brightnessctl
        clipse
        wl-clip-persist
        wl-clipboard

      ] ++ lib.optionals (pkgs.stdenv.hostPlatform.system == "x86_64-linux") [
        spotify
        discord
        protonmail-desktop
      ];

      fonts.packages = with pkgs; [
        nerd-fonts.jetbrains-mono
        nerd-fonts.fira-code
      ];


      # VM test variant
      virtualisation.vmVariant = {
        virtualisation.cores = 8;
        virtualisation.memorySize = 16384;
        virtualisation.resolution = { x = 1920; y = 1080; };
        users.users.${config.dotfiles.user.name} = {
          isNormalUser = true;
          password = "test";
          extraGroups = lib.optionals config.dotfiles.user.wheel [ "wheel" ];
        };
      };

      services.flatpak.enable = true;

      # Noctalia system services (when using noctalia statusbar)
      services.power-profiles-daemon.enable = lib.mkIf (config.dotfiles.windowManager.statusbar == "noctalia") true;
      services.upower.enable = lib.mkIf (config.dotfiles.windowManager.statusbar == "noctalia") true;

      # Home-manager desktop config
      home-manager.sharedModules = [
        inputs.nix-flatpak.homeManagerModules.nix-flatpak
      ];

      home-manager.users.${config.dotfiles.user.name} = { lib, pkgs, config, osConfig, ... }: {
        xdg.mimeApps = {
          enable = true;
          defaultApplications =
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

        xdg.portal = {
          enable = true;
          extraPortals = with pkgs; [
            xdg-desktop-portal-gtk
          ];
          config = {
            common = {
              default = [ "hyprland" "gtk" ];
              "org.freedesktop.impl.portal.FileChooser" = [ "gtk" ];
              "org.freedesktop.impl.portal.OpenURI" = [ "gtk" ];
            };
          };
        };

        gtk = {
          enable = true;
          theme = {
            name = "Tokyonight-Dark";
            package = pkgs.tokyonight-gtk-theme;
          };
          gtk3.extraConfig.gtk-application-prefer-dark-theme = 1;
          gtk4.extraConfig.gtk-application-prefer-dark-theme = 1;
        };

        qt = {
          enable = true;
          platformTheme.name = "gtk";
        };

        home.pointerCursor = {
          gtk.enable = true;
          x11.enable = true;
          size = 20;
          name = "material_light_cursors";
          package = pkgs.material-cursors;
        };

        services.flatpak = {
          enable = true;
          packages = [
            "com.github.iwalton3.jellyfin-media-player"
          ] ++ lib.optionals (pkgs.stdenv.hostPlatform.system == "x86_64-linux") [
            "app.grayjay.Grayjay"
            "page.codeberg.libre_menu_editor.LibreMenuEditor"
          ];
        };

        dconf.settings = {
          "org/gnome/desktop/interface" = {
            color-scheme = "prefer-dark";
            gtk-theme = "Tokyonight-Dark";
          };
        };

        home.sessionVariables = {
          XDG_THEME_MODE = "dark";
          DEFAULT_BROWSER = "${pkgs.firefox}/bin/firefox";
          BROWSER = "firefox";
          GTK_USE_PORTAL = "1";
          XCURSOR_SIZE = 35;
          GTK_THEME = "Tokyonight-Dark";
        };
      };
    };
}
