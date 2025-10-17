# Edit this configuration file to define what should be installed on
# your system.  Help is available in the configuration.nix(5) man page
# and in the NixOS manual (accessible by running ‘nixos-help’).

{ config, pkgs, pkgsUnstable, hyprland, ... }:

{
  imports =
    [ # Include the results of the hardware scan.
      ./hardware-configuration.nix
	  ./shares.nix
    ];

  # Bootloader.
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  networking.hostName = "nixos"; # Define your hostname.
  # networking.wireless.enable = true;  # Enables wireless support via wpa_supplicant.

  # Configure network proxy if necessary
  # networking.proxy.default = "http://user:password@proxy:port/";
  # networking.proxy.noProxy = "127.0.0.1,localhost,internal.domain";

  # Enable networking
  networking.networkmanager.enable = true;

  # Set your time zone.
  time.timeZone = "Europe/Zurich";

  # Select internationalisation properties.
  i18n.defaultLocale = "en_US.UTF-8";

  i18n.extraLocaleSettings = {
    LC_ADDRESS = "de_CH.UTF-8";
    LC_IDENTIFICATION = "de_CH.UTF-8";
    LC_MEASUREMENT = "de_CH.UTF-8";
    LC_MONETARY = "de_CH.UTF-8";
    LC_NAME = "de_CH.UTF-8";
    LC_NUMERIC = "de_CH.UTF-8";
    LC_PAPER = "de_CH.UTF-8";
    LC_TELEPHONE = "de_CH.UTF-8";
    LC_TIME = "de_CH.UTF-8";
  };

  # Enable the X11 windowing system.
  services.xserver.enable = true;

  # Enable the GNOME Desktop Environment.
  # services.xserver.displayManager.gdm.enable = true;
  # services.xserver.desktopManager.gnome.enable = true;

  # Configure keymap in X11
  services.xserver.xkb = {
    layout = "ch";
    variant = "";
  };

  # Configure console keymap
  console.keyMap = "sg";

  # Enable CUPS to print documents.
  services.printing.enable = true;

  # Enable sound with pipewire.
  services.pulseaudio.enable = false;
  security.rtkit.enable = true;
  services.pipewire = {
    enable = true;
    alsa.enable = true;
    alsa.support32Bit = true;
    pulse.enable = true;
    # If you want to use JACK applications, uncomment this
    #jack.enable = true;

    # use the example session manager (no others are packaged yet so this is enabled by default,
    # no need to redefine it in your config for now)
    #media-session.enable = true;
  };

  # Enable touchpad support (enabled default in most desktopManager).
  # services.xserver.libinput.enable = true;

  # Define a user account. Don't forget to set a password with ‘passwd’.
  users.users.simon = {
    isNormalUser = true;
    description = "simon";
    extraGroups = [ "networkmanager" "wheel" ];
    packages = with pkgs; [
    #  thunderbird
    ];
  };

  hardware.openrazer = {
	enable = true;
	users = [ "simon?" ];
  };

  # Install firefox.
  programs.firefox.enable = true;
  programs.hyprland = {
    enable = true;
    package = hyprland.packages.${pkgs.stdenv.hostPlatform.system}.hyprland;
    portalPackage = hyprland.packages.${pkgs.stdenv.hostPlatform.system}.xdg-desktop-portal-hyprland;
  };

  hardware.enableAllFirmware = true;

  # boot.kernelPatches = [
  #   {
  #     name = "amdgpu-ignore-ctx-privileges";
  #     patch = pkgs.fetchpatch {
  #       name = "cap_sys_nice_begone.patch";
  #       url = "https://github.com/Frogging-Family/community-patches/raw/master/linux61-tkg/cap_sys_nice_begone.mypatch";
  #       hash = "sha256-Y3a0+x2xvHsfLax/uwycdJf3xLxvVfkfDVqjkxNaYEo=";
  #     };
  #   }
  # ];
programs.steam = let
  patchedBwrap = pkgs.bubblewrap.overrideAttrs (o: {
    patches = (o.patches or []) ++ [
      ./bwrap.patch
    ];
  });
in {
  enable = true;
  # package = pkgs.steam.override {
  #   buildFHSEnv = (args: ((pkgs.buildFHSEnv.override {
  #     bubblewrap = patchedBwrap;
  #   }) (args // {
  #     extraBwrapArgs = (args.extraBwrapArgs or []) ++ [ "--cap-add ALL" ];
  #   })));
  # };
    remotePlay.openFirewall = true; # Open ports in the firewall for Steam Remote Play
    dedicatedServer.openFirewall = true; # Open ports in the firewall for Source Dedicated Server
    localNetworkGameTransfers.openFirewall = true; # Open ports in the firewall for Steam Local Network Game Transfers
};

  # programs.steam = {
  #   enable = true;
  #   remotePlay.openFirewall = true; # Open ports in the firewall for Steam Remote Play
  #   dedicatedServer.openFirewall = true; # Open ports in the firewall for Source Dedicated Server
  #   localNetworkGameTransfers.openFirewall = true; # Open ports in the firewall for Steam Local Network Game Transfers
  # };
  services.wivrn = {
    enable = true;
    openFirewall = true;

    # Write information to /etc/xdg/openxr/1/active_runtime.json, VR applications
    # will automatically read this and work with WiVRn (Note: This does not currently
    # apply for games run in Valve's Proton)
    defaultRuntime = true;

    # Run WiVRn as a systemd service on startup
    autoStart = true;

    # Config for WiVRn (https://github.com/WiVRn/WiVRn/blob/master/docs/configuration.md)
    config = {
      enable = true;
      json = {
        # 1.0x foveation scaling
        scale = 1.0;
        # 100 Mb/s
        bitrate = 100000000;
        encoders = [
          {
            encoder = "vaapi";
            codec = "h265";
            # 1.0 x 1.0 scaling
            width = 1.0;
            height = 1.0;
            offset_x = 0.0;
            offset_y = 0.0;
          }
        ];
      };
    };
  };

  # List packages installed in system profile. To search, run:
  # $ nix search wget
  environment.systemPackages = with pkgs; [
    vim
    kitty
    hyprland
    hyprlock
    wofi
	gcc
    # git
    home-manager
    tree
    wget
	lm_sensors
	libsecret
	# pkgsUnstable.fancontrol-gui
    # pulsemeeter
  ];

  boot.kernelModules = [ "coretemp" "nct6775" ];

  services.udev.extraRules = ''
    ACTION=="add", SUBSYSTEM=="hwmon", ATTR{name}=="coretemp", ATTRS{temp1_label}=="Package id 0", RUN+="/bin/sh -c 'ln -s /sys$devpath/temp1_input /dev/cpu_temp'"
  #   ACTION=="add", SUBSYSTEM=="hwmon", KERNELS=="nct6775.656", DRIVERS=="nct6775", RUN+="/bin/sh -c 'ln -s /sys$devpath/pwm2 /dev/cpu_fan'"
  #   ACTION=="add", SUBSYSTEM=="hwmon", KERNELS=="nct6775.656", DRIVERS=="nct6775", RUN+="/bin/sh -c 'ln -s /sys$devpath/pwm2_input /dev/cpu_fan_input'"
  #   ACTION=="add", SUBSYSTEM=="hwmon", KERNELS=="nct6774.656", DRIVERS=="nct6775", RUN+="/bin/sh -c 'ln -s /sys$devpath/pwm6 /dev/case_fan'"
  #   ACTION=="add", SUBSYSTEM=="hwmon", KERNELS=="nct6774.656", DRIVERS=="nct6775", RUN+="/bin/sh -c 'ln -s /sys$devpath/pwm6_input /dev/case_fan_input'"
  '';

	#  hardware.fancontrol = {
	# enable = true;
	# config = ''
	# INTERVAL=10
	# DEVPATH=hwmon4=devices/platform/nct6775.656
	# DEVNAME=hwmon4=nct6798
	# FCTEMPS=devices/platform/nct6775.656/hwmon/hwmon*/pwm6=devices/platform/nct6775.656/hwmon/hwmon*/temp1_input devices/platform/nct6775.656/hwmon/hwmon*/pwm2=devices/platform/nct6775.656/hwmon/hwmon*/temp1_input
	# FCFANS=devices/platform/nct6775.656/hwmon/hwmon*/pwm6=devices/platform/nct6775.656/hwmon/hwmon*/pwm6_input devices/platform/nct6775.656/hwmon/hwmon*/pwm2=devices/platform/nct6775.656/hwmon/hwmon*/pwm2_input
	# MINTEMP=devices/platform/nct6775.656/hwmon/hwmon*/pwm6=50 devices/platform/nct6775.656/hwmon/hwmon*/pwm2=2s5
	# MAXTEMP=devices/platform/nct6775.656/hwmon/hwmon*/pwm6=95 devices/platform/nct6775.656/hwmon/hwmon*/pwm2=70
	# MINSTART=devices/platform/nct6775.656/hwmon/hwmon*/pwm6=34 devices/platform/nct6775.656/hwmon/hwmon*/pwm2=66
	# MINSTOP=devices/platform/nct6775.656/hwmon/hwmon*/pwm6=4 devices/platform/nct6775.656/hwmon/hwmon*/pwm2=26
	# MINPWM=devices/platform/nct6775.656/hwmon/hwmon*/pwm6=4 devices/platform/nct6775.656/hwmon/hwmon*/pwm2=20
	# MAXPWM=devices/platform/nct6775.656/hwmon/hwmon*/pwm6=150 devices/platform/nct6775.656/hwmon/hwmon*/pwm2=255
	# '';
	#  };

	#  hardware.fancontrol = {
	# enable = true;
	# config = ''
	#   INTERVAL=10
	#   DEVPATH=hwmon*=devices/platform/nct6775.656
	#   DEVNAME=hwmon*=nct6798
	#   FCTEMPS=/dev/case_fan=/dev/cpu_temp /dev/cpu_fan=/dev/cpu_temp
	#   FCFANS=/dev/case_fan=/dev/case_fan_input /dev/cpu_fan=/dev/cpu_fan_input
	#   MINTEMP=/dev/case_fan=50 /dev/cpu_fan=2s5
	#   MAXTEMP=/dev/case_fan=95 /dev/cpu_fan=70
	#   MINSTART=/dev/case_fan=34 /dev/cpu_fan=66
	#   MINSTOP=/dev/case_fan=4 /dev/cpu_fan=26
	#   MINPWM=/dev/case_fan=4 /dev/cpu_fan=20
	#   MAXPWM=/dev/case_fan=150 /dev/cpu_fan=255
	# '';
	#  };

  systemd.services.fancontrol.enable = true;

  fonts.packages = with pkgs; [
	nerd-fonts.jetbrains-mono
	nerd-fonts.fira-code
  ];

  nix.settings = {
    substituters = ["https://hyprland.cachix.org"];
    trusted-substituters = ["https://hyprland.cachix.org"];
    trusted-public-keys = ["hyprland.cachix.org-1:a7pgxzMz7+chwVL3/pzj6jIBMioiJM7ypFP8PwtkuGc="];
  };

  nix.settings.experimental-features = [ "nix-command" "flakes" ];

  services.gnome.gnome-keyring.enable = true;
  security.pam.services.hyprland.enableGnomeKeyring = true;
  security.pam.services.lightdm.enableGnomeKeyring = true;
  security.pam.services.login.enableGnomeKeyring = true;

  programs._1password.enable = true;
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
