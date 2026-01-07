{ lib, pkgs, pkgs-stable, config, dms, ... }: 
let
  username = "simon";
in {
  imports = [
		dms.homeModules.dankMaterialShell.default
		./programs/dms.nix
		./programs/kitty.nix
		./programs/swappy.nix
		./programs/easyeffects/easyeffects.nix
		./programs/mpv.nix
		./programs/vr/wlx-overlay-s.nix
		./programs/orca-slicer.nix
		./programs/udiskie.nix
		./programs/yazi.nix
		./general/links.nix
  ];

  programs.neovim.enable = true;
  xdg.configFile."nvim".source = ./nvim;

  gtk = {
		enable = true;
		theme = {
			name = "Tokyonight-Dark";
			package = pkgs.tokyonight-gtk-theme;
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
			spotify
			discord
			material-cursors
			protonmail-desktop
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
			qmk
			qmk_hid
			qmk-udev-rules
			vial
			losslesscut-bin
			jellyfin-mpv-shim
			gtk3-x11
			gimp
			fsearch
			libreoffice
    ];

	sessionVariables = {
		XDG_THEME_MODE = "dark";
		DEFAULT_BROWSER = "${pkgs.firefox}/bin/firefox";
		XCURSOR_SIZE = 35;
	};

    stateVersion = "23.11";
  };
}
