{ pkgs, config, lib, ... }:
{
  config = lib.mkIf (config.dotfiles.bootloader == "grub") {
    boot.loader.grub.enable = true;
    boot.loader.grub.gfxmodeEfi = "max";
    boot.loader.grub.useOSProber = true;
    boot.loader.grub.device = config.dotfiles.grubDevice;
  };
}
