{ lib, pkgs, pkgs-stable, config, ... }: 
let
  username = "simon";
in {
xdg.configFile."niri/config.kdl".source = ./config.kdl;
  home = {
		stateVersion = "23.11";
	};
}
