{ pkgs, ... }:
{
  imports = [
	  ./gaming/gaming.nix
	];
  services.xserver.videoDrivers = ["nvidia"];
  hardware.nvidia = {
		modesetting.enable = true;
		open = false;
		package = config.boot.kernelPackages.nvidiaPackages.stable;
	};
}
