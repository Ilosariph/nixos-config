{ config, pkgs, ... }:
{
	programs.niri.enable = true;
  xdg.portal = {
    enable = true;
    extraPortals = [
			pkgs.xdg-desktop-portal-gtk
		];
		config.common.default = [
			"niri"
			"gtk"
		];
  };

	security.polkit.enable = true;
  services.gnome.gnome-keyring.enable = true;
  security.pam.services.swaylock = {};
	environment.systemPackages = with pkgs; [
		swaylock
		mako
		swayidle
	];
}
