{ pkgs, config, lib, pc, ... }:
{
  config = lib.mkIf (config.dotfiles.bootloader == "systemd") {
    boot.loader.systemd-boot.enable = true;
    # boot.loader.systemd-boot.consoleMode = "max";
    boot.loader.efi.canTouchEfiVariables = if pc == "macbook" then false else true;
  };
}
