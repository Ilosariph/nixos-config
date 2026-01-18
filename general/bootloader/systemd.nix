{ pkgs, config, ... }:
{
  boot.loader.systemd-boot.enable = true;
	boot.loader.systemd-boot.consoleMode = "max";
	boot.loader.efi.canTouchEfiVariables = true;
}
