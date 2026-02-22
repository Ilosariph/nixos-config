{ lib, pkgs, config, ... }:
let
  username = "simon";
  wallpaperDir = pkgs.stdenv.mkDerivation {
    name = "wallpapers";
    src =  ./hypr/hyprpaper/wallpapers;# Path relative to the Nix file
    installPhase = "mkdir -p $out && cp -r $src/* $out";
  };
in {
  home.sessionVariables = {
    WALLPAPER_DIR = "${wallpaperDir}";
  };
  imports = [
    ./hypr/hyprland.nix
		./hypr/hypridle.nix
		./hypr/hyprlock.nix
		./hypr/hyprpaper/hyprpaper.nix
  ];
  xdg.portal = {
    extraPortals = with pkgs; [
      xdg-desktop-portal-hyprland
    ];
  };

  services.hyprpolkitagent.enable = true;


  home.pointerCursor = {
		hyprcursor.enable = true;
		hyprcursor.size = 35;
  };

  home = {
    inherit username;
    homeDirectory = "/home/${username}";

    packages = with pkgs; [
			hyprpaper
    ];

    stateVersion = "23.11";
  };
}
