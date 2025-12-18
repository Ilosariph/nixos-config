{ lib, pkgs, pkgs-stable, config, walker, ... }: 
{
  imports = [
    ./hypr/hyprland.nix
    ./hypr/hyprlock.nix
    ./hypr/hyprpanel.nix
	./hypr/hypridle.nix
	walker.homeManagerModules.default
	./hypr/walker.nix
	./programs/kitty.nix
	./programs/swappy.nix
	./programs/easyeffects/easyeffects.nix
	./programs/mpv.nix
	./programs/orca-slicer.nix
	./programs/udiskie.nix
	./programs/yazi.nix
  ];

  programs.neovim.enable = true;
  xdg.configFile."nvim".source = ./nvim;

  services.hyprpolkitagent.enable = true;


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
	hyprcursor.enable = true;
	hyprcursor.size = 35;
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
	  hyprpaper
	  libnotify
	  chromium
	  spotify
	  material-cursors
	  protonmail-desktop
	  github-desktop
	  obsidian
	  pavucontrol
	  qview
	  filezilla
	  grimblast
	  jetbrains.pycharm-professional
	  orca-slicer
	  udisks
    ];

	sessionVariables = {
      XDG_THEME_MODE = "dark";
	  DEFAULT_BROWSER = "${pkgs.firefox}/bin/firefox";
	  XCURSOR_SIZE = 35;
    };

    stateVersion = "23.11";
  };
}
