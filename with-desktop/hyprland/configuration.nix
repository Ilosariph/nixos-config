{ config, pkgs, pkgs-unstable, hyprland, ... }:
{
  programs.hyprland = {
    enable = true;
  };

  environment.sessionVariables = {
    XDG_CURRENT_DESKTOP = "Hyprland";
    XDG_SESSION_DESKTOP = "Hyprland";
    XDG_SESSION_TYPE = "wayland";
  };

  systemd.user.services.xdg-desktop-portal-hyprland.wantedBy = [ "hyprland-session.target" ];
  systemd.user.services.xdg-desktop-portal-gtk.wantedBy = [ "hyprland-session.target" ];

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
