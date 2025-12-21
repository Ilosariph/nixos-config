{ lib, pkgs, pkgs-stable, config, ... }: 
{
  wayland.windowManager.hyprland.settings = {
		monitor = [
		];#todo

		"$left" = "H";
		"$right" = "L";
		"$up" = "K";
		"$down" = "J";
	};
}
