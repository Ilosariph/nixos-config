{ lib, pkgs, ... }:
{
  dotfiles.bootloader = "grub";
  dotfiles.grubDevice = "/dev/nvme0n1";
  dotfiles.vpn = false;
  dotfiles.hyprland.settings = {
    monitors = [
      "eDP-1, 1920x1080@59.99900, 0x0, 1"
    ];
  };
}
