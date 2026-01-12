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
			path = "/home/simon/.ssh/id_ed25519.pub";
    };
  };

	services.openssh.enable = true;
}
