{ lib, pkgs, pkgs-stable, config, ... }:
let
  username = "simon";
in {
  imports = [
		./programs/waybar.nix
		./programs/kitty.nix
		./programs/bash.nix
		./programs/fish.nix
		./programs/swappy.nix
		./programs/easyeffects/easyeffects.nix
		./programs/mpv.nix
		./programs/vr/wlx-overlay-s.nix
		./programs/orca-slicer.nix
		./programs/udiskie.nix
		./programs/yazi.nix
		./programs/zed.nix
		./general/links.nix
  ];

  programs.neovim.enable = true;
  xdg.configFile."nvim".source = ./nvim;

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
    in
    {
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
		gtk3.extraConfig = {
			gtk-application-prefer-dark-theme = 1;
		};
		gtk4.extraConfig = {
			gtk-application-prefer-dark-theme = 1;
		};
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

  home = {
		inherit username;
		homeDirectory = "/home/${username}";

    packages = with pkgs; [
			kdePackages.dolphin
			wl-clipboard
			libnotify
			chromium
			firefox
			material-cursors
			github-desktop
			obsidian
			seahorse
			pavucontrol
			razergenie
			qview
			filezilla
			grimblast
			qpwgraph
			jetbrains.pycharm-professional
			orca-slicer
			udisks
			vlc
			jellyfin-mpv-shim
			gtk3-x11
			gimp
			fsearch
			libreoffice
			gsettings-desktop-schemas
			glib
			desktop-file-utils
			# System monitor
			btop
			# Bluetooth manager
			blueberry
			# WiFi / network manager GUI
			networkmanagerapplet
			# Launcher (replaces DMS spotlight)
			wofi
			# Color picker
			hyprpicker
			# Media key control
			playerctl
			# Brightness control
			brightnessctl
			# Clipboard manager
			clipse
			wl-clip-persist
    ] ++ lib.optionals (pkgs.stdenv.hostPlatform.system == "x86_64-linux") [
			spotify
			discord
			protonmail-desktop
	];

  	sessionVariables = {
  		XDG_THEME_MODE = "dark";
  		DEFAULT_BROWSER = "${pkgs.firefox}/bin/firefox";
  		BROWSER = "firefox";
  		GTK_USE_PORTAL = "1";
  		XCURSOR_SIZE = 35;
  		GTK_THEME = "Tokyonight-Dark";
  	};

    stateVersion = "23.11";
  };

  dconf.settings = {
    "org/gnome/desktop/interface" = {
      color-scheme = "prefer-dark";
      gtk-theme = "Tokyonight-Dark";
    };
  };
}
