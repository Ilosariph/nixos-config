{ lib, pkgs, pkgs-stable, config, dms, ... }:
let
  username = "simon";
in {
  imports = [
		# dms.homeModules.dankMaterialShell.default
		# ./programs/dms.nix
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

    ];

	sessionVariables = {
		XDG_THEME_MODE = "dark";
		DEFAULT_BROWSER = "${pkgs.firefox}/bin/firefox";
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
