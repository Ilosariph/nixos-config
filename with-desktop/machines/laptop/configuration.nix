{ pkgs, ... }:
{
	boot.loader.grub.device = "/dev/nvme0n1";
	boot.kernelPackages = pkgs.linuxPackages_latest;
}
