{ lib, pkgs, ... }:
{
  dotfiles.desktop.enable = true;
  dotfiles.programs.tmux.enable = false;
  dotfiles.windowManager.type = "hyprland";
  dotfiles.bluetooth.enable = true;
  dotfiles.bootloader.type = "grub";
  dotfiles.bootloader.grubDevice = "/dev/nvme0n1";
  dotfiles.windowManager.mainMonitor = "eDP-1";
  dotfiles.windowManager.settings = {
    monitors = [
      "eDP-1, 1920x1080@59.99900, 0x0, 1"
    ];
  };
}
