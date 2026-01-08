{ pkgs, ... }:
{
	boot.loader.grub.enable = true;
	boot.loader.grub.device = "/dev/nvme0n1";
	boot.loader.grub.useOSProber = true;
	boot.kernelPackages = pkgs.linuxPackages_latest;
	services.xserver.xkb = {
		layout = "ch";
	};
	users.users."simon".openssh.authorizedKeys.keyFiles = [
		"/etc/nixos/nucserver-ssh-key"
	];
}
