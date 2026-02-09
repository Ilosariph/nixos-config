{ pkgs, ... }:
{
	imports =
		[ # Include the results of the hardware scan.
			./apple-silicon-support
			./touchbar.nix
		];
  networking.networkmanager.enable = true;
  networking.wireless.iwd = {
    enable = true;
    settings.General.EnableNetworkConfiguration = true;
  };

	hardware.asahi.peripheralFirmwareDirectory = ./firmware;
	# hardware.asahi.useExperimentalGPUDriver = true;

  boot.extraModprobeConfig = ''
    options hid_apple iso_layout=1 swap_opt_cmd=1 swap_fn_leftctrl=1
  '';
}
