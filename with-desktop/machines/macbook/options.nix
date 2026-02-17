{ lib, pkgs, ... }:
{
  dotfiles.vpn = true;
  dotfiles.hyprland.settings = {
    monitors = [
      "eDP-1, 2560x1600@60.00000, 0x0, 1.3333334"
    ];
  };
}
