{ pkgs, ... }:
{
  imports = [
		../general/ssh/ssh-with-nucserver-key.nix
  ];

	boot.kernelPackages = pkgs.linuxPackages_latest;
}
