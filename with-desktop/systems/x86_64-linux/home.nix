{ pkgs, ... }:
{
  services.flatpak = {
		enable = true;
		packages = [
			"app.grayjay.Grayjay"
			"page.codeberg.libre_menu_editor.LibreMenuEditor"
		];
	};
	home.packages = with pkgs; [
		spotify
		discord
		protonmail-desktop
	];
}
