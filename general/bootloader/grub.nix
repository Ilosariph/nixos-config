{ pkgs, ... }:
{
	boot.loader.grub.enable = true;
	boot.loader.grub.gfxmodeEfi = "max";
	boot.loader.grub.useOSProber = true;
}
