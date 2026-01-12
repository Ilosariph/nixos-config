{ config, pkgs, ... }:
{
	boot.loader.grub.enable = true;
	boot.loader.grub.device = "/dev/nvme0n1";
	boot.loader.grub.useOSProber = true;
	boot.kernelPackages = pkgs.linuxPackages_latest;

	sops = {
		age.keyFile = "/home/simon/.config/sops/age/keys.txt";
		defaultSopsFile = ../../../secrets.yaml;

		secrets.nucserver-ssh-public-key = {
			path = "/home/simon/.ssh/authorized_keys";
			owner = "simon";
			group = "users";
			mode = "0400";
		};
	};

	services.openssh.enable = true;
}
