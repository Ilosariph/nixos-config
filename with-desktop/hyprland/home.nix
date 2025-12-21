{ lib, pkgs, pkgs-stable, config, dms, ... }: 
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
		dms.homeModules.dankMaterialShell.default
		./hypr/dms.nix
  ];

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
