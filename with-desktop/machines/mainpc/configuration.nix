{ pkgs, config, ... }:
{
  imports = [
	  ./gaming/gaming.nix
	];
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;
  services.xserver.videoDrivers = ["nvidia"];
  hardware.nvidia = {
		modesetting.enable = true;
		open = false;
		package = config.boot.kernelPackages.nvidiaPackages.stable;
	};
}
