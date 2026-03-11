{ lib, pkgs, ... }:
{
  dotfiles.desktop.enable = true;
  dotfiles.windowManager.type = "hyprland";
  dotfiles.bluetooth.enable = true;
  dotfiles.windowManager.mainMonitor = "eDP-1";
	dotfiles.windowManager.statusbar = "noctalia";
  dotfiles.vpn = {
    enable = true;
    accounts = [ "home" "proton" ];
  };
  dotfiles.programs.virtualisation.enable = false;
  dotfiles.windowManager.settings = {
    monitors = [
      "eDP-1, 2560x1600@60.00000, 0x0, 1.3333334"
    ];
  };
}
