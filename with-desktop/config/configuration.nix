# Edit this configuration file to define what should be installed on
# your system.  Help is available in the configuration.nix(5) man page
# and in the NixOS manual (accessible by running ‘nixos-help’).
{ config, pkgs, pkgs-unstable, ... }:
{
  imports =
    [
	  ./drives.nix
	  ./shares.nix
	  ./virtualisation.nix
	  ./network.nix
	  ./gaming/gaming.nix
    ];

  services.xserver.enable = true;

  services.xserver.xkb = {
    layout = "ch";
    variant = "";
  };

  console.keyMap = "sg";

  services.printing.enable = true;

  services.pulseaudio.enable = false;
  security.rtkit.enable = true;
  services.pipewire = {
    enable = true;
    alsa.enable = true;
    alsa.support32Bit = true;
    pulse.enable = true;
  };

  services.udev.packages = [
	pkgs.qmk-udev-rules
	pkgs.vial
  ];

  # Define a user account. Don't forget to set a password with ‘passwd’.
  users.users.simon = {
    extraGroups = [ "networkmanager" "wheel" "libvirtd" "openrazer" ];
  };

  services.udisks2.enable = true;
  services.gvfs.enable = true;

  hardware.openrazer = {
	enable = true;
  };

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
    # git
		polychromatic
    home-manager
		lm_sensors
		libsecret
	# pkgs-unstable.fancontrol-gui
    pkgs-unstable.pulsemeeter
		protonvpn-gui
		pulseaudio
		spice-gtk
  ];

  services.flatpak.enable = true;

  boot.kernelModules = [ "coretemp" "nct6775" ];

  services.udev.extraRules = ''
    ACTION=="add", SUBSYSTEM=="hwmon", ATTR{name}=="coretemp", ATTRS{temp1_label}=="Package id 0", RUN+="/bin/sh -c 'ln -s /sys$devpath/temp1_input /dev/cpu_temp'"
  #   ACTION=="add", SUBSYSTEM=="hwmon", KERNELS=="nct6775.656", DRIVERS=="nct6775", RUN+="/bin/sh -c 'ln -s /sys$devpath/pwm2 /dev/cpu_fan'"
  #   ACTION=="add", SUBSYSTEM=="hwmon", KERNELS=="nct6775.656", DRIVERS=="nct6775", RUN+="/bin/sh -c 'ln -s /sys$devpath/pwm2_input /dev/cpu_fan_input'"
  #   ACTION=="add", SUBSYSTEM=="hwmon", KERNELS=="nct6774.656", DRIVERS=="nct6775", RUN+="/bin/sh -c 'ln -s /sys$devpath/pwm6 /dev/case_fan'"
  #   ACTION=="add", SUBSYSTEM=="hwmon", KERNELS=="nct6774.656", DRIVERS=="nct6775", RUN+="/bin/sh -c 'ln -s /sys$devpath/pwm6_input /dev/case_fan_input'"
  '';

  systemd.services.fancontrol.enable = true;

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

  services.xserver.videoDrivers = ["nvidia"];
  hardware.nvidia = {
		modesetting.enable = true;
		open = false;
		package = config.boot.kernelPackages.nvidiaPackages.stable;
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
