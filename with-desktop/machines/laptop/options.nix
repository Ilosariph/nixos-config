{ lib, pkgs, ... }:
{
  dotfiles.bluetooth.enable = true;
  dotfiles.bootloader = "grub";
  dotfiles.grubDevice = "/dev/nvme0n1";
  dotfiles.hyprland.mainMonitor = "eDP-1";
  dotfiles.hyprland.settings = {
    monitors = [
      "eDP-1, 1920x1080@59.99900, 0x0, 1"
    ];
  };
}
