{ pkgs, ... }
{
  services.flatpak = {
		enable = true;
		packages = [
			"app.grayjay.Grayjay"
			"page.codeberg.libre_menu_editor.LibreMenuEditor"
		];
	};
    packages = with pkgs; [
			spotify
			discord
			protonmail-desktop
		];
}
