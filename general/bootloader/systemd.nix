{ pkgs, config, lib, pc, ... }:
{
  config = lib.mkIf (config.dotfiles.bootloader == "systemd") {
    boot.loader.systemd-boot.enable = true;
    boot.loader.systemd-boot.consoleMode = if pkgs.stdenv.hostPlatform.system == "x86_64-linux" then "max" else "0";
    boot.loader.efi.canTouchEfiVariables = if pc == "macbook" then false else true;
  };
}
