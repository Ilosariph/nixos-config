{ pkgs, ... }:
{
  imports = [
		../general/ssh/ssh-with-nucserver-key.nix
	  ./docker/arr.nix
  ];

	boot.loader.grub.device = "/dev/nvme0n1";
	boot.kernelPackages = pkgs.linuxPackages_latest;
}
