{ config, pkgs, pkgs-unstable, hyprland, ... }:
{
  programs.hyprland = {
    enable = true;
  };
  xdg.portal = {
    enable = true;
    extraPortals = [
			pkgs.xdg-desktop-portal-gtk
			pkgs.xdg-desktop-portal-hyprland
		];
		config.common.default = [
			"hyprland"
			"gtk"
		];
  };

  environment.systemPackages = with pkgs; [
    hyprland
    hyprlock
	];
  nix.settings = {
    substituters = ["https://hyprland.cachix.org"];
    trusted-substituters = ["https://hyprland.cachix.org"];
    trusted-public-keys = ["hyprland.cachix.org-1:a7pgxzMz7+chwVL3/pzj6jIBMioiJM7ypFP8PwtkuGc="];
  };
  services.gnome.gnome-keyring.enable = true;
  security.pam.services.hyprland.enableGnomeKeyring = true;
  security.pam.services.lightdm.enableGnomeKeyring = true;
  security.pam.services.login.enableGnomeKeyring = true;
}
