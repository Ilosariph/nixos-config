{ lib, pkgs, pkgs-stable, config, ... }: 
{
  wayland.windowManager.hyprland.settings = {
		monitor = [
			"eDP-1, 1920x1080@59.99900, 0x0, 1"
		];

		"$left" = "H";
		"$right" = "L";
		"$up" = "K";
		"$down" = "J";
	};
}
