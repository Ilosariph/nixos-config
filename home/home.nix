{ lib, pkgs, ... }: 
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
  ];

  programs.ssh = {
    enable = true;
    extraConfig = ''
      Host *
          IdentityAgent ${onePassPath}
    '';
  };
  programs.git = {
	extraConfig = {
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
        signingKey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIDk/LW0RX25BW64tJrsU7VFMqlSPR6zto9lAYghBLvie";
      };
    };
  };
  # programs.git = {
  #   enable = true;
  #   extraConfig = {
  #     gpg = {
  #       format = "ssh";
  #     };
  #     "gpg \"ssh\"" = {
  #       program = "${lib.getExe' pkgs._1password-gui "op-ssh-sign"}";
  #     };
  #     commit = {
  #       gpgsign = true;
  #     };
  #
  #     user = {
  #       signingKey = "...";
  #     };
  #   };
  # };

  programs.neovim.enable = true;
  xdg.configFile."nvim".source = ./nvim;

  programs.mpv = {
	enable = true;
  };

  services.swaync.enable = true;
  services.hyprpolkitagent.enable = true;

  xdg.mimeApps = {
	enable = true;
	defaultApplications = {
      "text/html" = "firefox.desktop";
      "x-scheme-handler/http" = "firefox.desktop";
      "x-scheme-handler/https" = "firefox.desktop";
      "x-scheme-handler/about" = "firefox.desktop";
      "x-scheme-handler/unknown" = "firefox.desktop";
    };
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
      nautilus
      hyprshot
	  hyprpaper
	  libnotify
	  chromium
	  spotify
      discord
      grayjay
	  material-cursors
	  protonmail-desktop
	  github-desktop
	  obsidian
	  seahorse
    ];

	sessionVariables = {
      XDG_THEME_MODE = "dark";
	  DEFAULT_BROWSER = "${pkgs.firefox}/bin/firefox";
	  XCURSOR_SIZE = 35;
    };

    stateVersion = "23.11";
  };
}
