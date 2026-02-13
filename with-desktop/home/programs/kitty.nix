{ pkgs, ... }:
{
	programs.kitty = {
		enable = true;
		themeFile = "tokyo_night_night";
		font.name = "Jetbrains Mono";
		font.package = pkgs.jetbrains-mono;
		settings = {
			background_opacity = 0.9;
			shell = "${pkgs.fish}/bin/fish"; 
		};
		shellIntegration = {
			mode = "enabled";
			enableFishIntegration = true;
		};
	};
}
