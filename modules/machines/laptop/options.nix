{ lib, pkgs, ... }:
{
  dotfiles.sops.enable = true;
  dotfiles.desktop.enable = true;
  dotfiles.programs.tmux.enable = false;
  dotfiles.programs.gnirehtet.enable = true;
  dotfiles.windowManager.type = "niri";
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
