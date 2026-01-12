{ pkgs, ... }:
{
	boot.loader.grub.enable = true;
	boot.loader.grub.device = "/dev/nvme0n1";
	boot.loader.grub.useOSProber = true;
	boot.kernelPackages = pkgs.linuxPackages_latest;
	services.openssh.enable = true;
	users.users."simon".openssh.authorizedKeys.keyFiles = [
		"/etc/nixos/nucserver-ssh-key"
	];
}
