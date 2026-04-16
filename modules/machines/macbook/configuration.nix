{ pkgs, ... }:
{
	imports =
		[ # Include the results of the hardware scan.
			./touchbar.nix
		];

  # Asahi kernel is set by apple-silicon-support module (linuxPackages_asahi).
  # Binary cache avoids rebuilding the kernel locally.
  nix.settings = {
    extra-substituters = [ "https://nixos-apple-silicon.cachix.org" ];
    extra-trusted-public-keys = [ "nixos-apple-silicon.cachix.org-1:8psDu5SA5dAD7qA0zMy5UT292TxeEPzIz8VVEr2Js20=" ];
  };

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
