{ lib, pkgs, pkgs-stable, config, ... }: 
{
  wayland.windowManager.hyprland.settings = {
		monitor = [
			"eDP-1, 2560x1600@60.00000, 0x0, 1.3333334"
		];

		"$left" = "H";
		"$right" = "L";
		"$up" = "K";
		"$down" = "J";
	};
}
