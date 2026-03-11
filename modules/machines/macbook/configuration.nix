{ pkgs, ... }:
{
	imports =
		[ # Include the results of the hardware scan.
			./touchbar.nix
		];
  networking.networkmanager.enable = true;
  networking.networkmanager.wifi.backend = "iwd";
  networking.wireless.enable = false;
  networking.wireless.iwd = {
    enable = true;
    settings.General.EnableNetworkConfiguration = true;
  };

	hardware.asahi.peripheralFirmwareDirectory = ./firmware;
	# hardware.asahi.useExperimentalGPUDriver = true;

  boot.extraModprobeConfig = ''
    options hid_apple iso_layout=1 swap_opt_cmd=1 swap_fn_leftctrl=1
  '';

  # Apple Silicon requires canTouchEfiVariables = false
  boot.loader.efi.canTouchEfiVariables = false;
}
