{ pkgs, ... }:
{
	boot.loader.grub.enable = true;
	boot.loader.grub.gfxmodeEfi = "max";
	boot.loader.grub.device = "/dev/nvme0n1";
	boot.loader.grub.useOSProber = true;
	boot.kernelPackages = pkgs.linuxPackages_latest;
}
