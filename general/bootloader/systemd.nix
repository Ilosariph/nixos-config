{ pkgs, config, pc, ... }:
{
  boot.loader.systemd-boot.enable = true;
	# boot.loader.systemd-boot.consoleMode = "max";
	boot.loader.efi.canTouchEfiVariables = if pc == "macbook" then false else true;
}
