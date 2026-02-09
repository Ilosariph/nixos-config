# Edit this configuration file to define what should be installed on
# your system.  Help is available in the configuration.nix(5) man page
# and in the NixOS manual (accessible by running ‘nixos-help’).
{ config, pkgs, ... }:
{
	imports = [
	  ./shares.nix
	  ./virtualisation.nix
	  ./network.nix
	];

	programs.dms-shell = {
		enable = true;

		# systemd = {
		# 	enable = true;             # Systemd service for auto-start
		# 	restartIfChanged = true;   # Auto-restart dms.service when dms-shell changes
		# };
		
		# Core features
		enableSystemMonitoring = true;     # System monitoring widgets (dgop)
		enableClipboard = true;            # Clipboard history manager
		enableVPN = true;                  # VPN management widget
		enableDynamicTheming = true;       # Wallpaper-based theming (matugen)
		enableAudioWavelength = true;      # Audio visualizer (cava)
		enableCalendarEvents = true;       # Calendar integration (khal)
	};

  services.printing.enable = true;

  services.pulseaudio.enable = false;
  security.rtkit.enable = true;
  services.pipewire = {
    enable = true;
    alsa.enable = true;
    alsa.support32Bit = true;
    pulse.enable = true;
  };

	services.xserver.enable = true;

  users.users.simon = {
    extraGroups = [ "libvirtd" ];
  };

  services.udisks2.enable = true;
  services.gvfs.enable = true;

  programs.firefox.enable = true;

  xdg.mime = {
		defaultApplications =
		let
			browser = "firefox.desktop";
			imgViewer = "com.interversehq.qView.desktop";
			vidViewer = "mpv.desktop";
			fileManager = "org.kde.dolphin.desktop";
		in
		{
			"image/png" = imgViewer;
			"image/webp" = imgViewer;
			"image/jpeg" = imgViewer;

			"inode/directory" = fileManager;
			"video/avi" = vidViewer;
			"video/flv" = vidViewer;
			"video/mp4" = vidViewer;
			"video/mpeg" = vidViewer;
			"video/webm" = vidViewer;
			"video/vnd.avi" = vidViewer;

			"application/pdf" = browser;

			"text/html" = browser;
			"x-scheme-handler/http" = browser;
			"x-scheme-handler/https" = browser;
			"x-scheme-handler/about" = browser;
			"x-scheme-handler/unknown" = browser;
			};
  };

  # List packages installed in system profile. To search, run:
  # $ nix search wget
  environment.systemPackages = with pkgs; [
    kitty
		gcc
		polychromatic
    home-manager
		lm_sensors
		libsecret
	# fancontrol-gui
    pulsemeeter
		protonvpn-gui
		pulseaudio
		spice-gtk
		gemini-cli
  ];

  services.flatpak.enable = true;

  fonts.packages = with pkgs; [
		nerd-fonts.jetbrains-mono
		nerd-fonts.fira-code
  ];

  programs._1password-gui = {
    enable = true;
    # Certain features, including CLI integration and system authentication support,
    # require enabling PolKit integration on some desktop environments (e.g. Plasma).
    polkitPolicyOwners = [ "simon" ];
  };

  hardware.graphics = {
    enable = true;
  };

  # Some programs need SUID wrappers, can be configured further or are
  # started in user sessions.
  # programs.mtr.enable = true;
  # programs.gnupg.agent = {
  #   enable = true;
  #   enableSSHSupport = true;
  # };

  # List services that you want to enable:

  # Enable the OpenSSH daemon.
  # services.openssh.enable = true;

  # Open ports in the firewall.
  # networking.firewall.allowedTCPPorts = [ ... ];
  # networking.firewall.allowedUDPPorts = [ ... ];
  # Or disable the firewall altogether.
  # networking.firewall.enable = false;

  # This value determines the NixOS release from which the default
  # settings for stateful data, like file locations and database versions
  # on your system were taken. It‘s perfectly fine and recommended to leave
  # this value at the release version of the first install of this system.
  # Before changing this value read the documentation for this option
  # (e.g. man configuration.nix or on https://nixos.org/nixos/options.html).
  system.stateVersion = "25.05"; # Did you read the comment?

}
