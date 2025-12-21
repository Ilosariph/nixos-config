{ lib, pkgs, pkgs-stable, config, walker, ... }: 
let
  username = "simon";
in {
xdg.configFile."niri/config.kdl".source = ./config.kdl;
  home = {
		stateVersion = "23.11";
	};
}
