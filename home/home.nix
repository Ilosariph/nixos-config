{ lib, pkgs, pkgs-stable, config, walker, ... }: 
let
  username = "simon";
  wallpaperDir = pkgs.stdenv.mkDerivation {
    name = "wallpapers";
    src =  ./hypr/hyprpaper/wallpapers;# Path relative to the Nix file
    installPhase = "mkdir -p $out && cp -r $src/* $out";
  };
  onePassPath = "~/.1password/agent.sock";
in {
  home.sessionVariables = {
    WALLPAPER_DIR = "${wallpaperDir}";
  };
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
  ];

  programs.ssh = {
	enable = true;
	enableDefaultConfig = false;
	matchBlocks."*" = {
	  forwardAgent = false;
	  serverAliveInterval = 0;
	  serverAliveCountMax = 3;
	  compression = false;
	  addKeysToAgent = "no";
	  hashKnownHosts = false;
	  controlMaster = "no";
	  controlPersist = "no";
	  extraOptions = {
		"Host" = ''
*
    IdentityAgent ${onePassPath}
		'';
	  };
	};
  };

  programs.git = {
	enable = true;
	settings = {
	  gpg = {
        format = "ssh";
      };
	     "gpg \"ssh\"" = {
	       program = "${lib.getExe' pkgs._1password-gui "op-ssh-sign"}";
	     };
      commit = {
        gpgsign = true;
      };

      user = {
		name = "Ilosariph";
		email = "71074737+Ilosariph@users.noreply.github.com";
        signingKey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIDk/LW0RX25BW64tJrsU7VFMqlSPR6zto9lAYghBLvie";
      };
    };
  };

  programs.neovim.enable = true;
  xdg.configFile."nvim".source = ./nvim;

  services.hyprpolkitagent.enable = true;


  gtk = {
	enable = true;
	theme = {
	  name = "Tokyonight-Dark";
	  package = pkgs.tokyo-night-gtk;
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

  home = {
    inherit username;
    homeDirectory = "/home/${username}";

    packages = with pkgs; [
      kdePackages.dolphin
	  yazi
	  wl-clipboard
	  hyprpaper
	  waybar-mpris
	  libnotify
	  chromium
	  spotify
      discord
	  unzip
	  material-cursors
	  protonmail-desktop
	  github-desktop
	  obsidian
	  seahorse
	  pavucontrol
	  razergenie
	  qview
	  filezilla
	  python312
	  grimblast
	  zip
	  streamcontroller
	  qpwgraph
	  jetbrains.pycharm-professional
    ];

	sessionVariables = {
      XDG_THEME_MODE = "dark";
	  DEFAULT_BROWSER = "${pkgs.firefox}/bin/firefox";
	  XCURSOR_SIZE = 35;
    };

    stateVersion = "23.11";
  };
}
