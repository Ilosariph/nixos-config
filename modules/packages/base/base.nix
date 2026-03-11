{ ... }: {
  flake.nixosModules.base = { config, pkgs, lib, ... }: {
    time.timeZone = config.dotfiles.locale.timeZone;

    i18n.defaultLocale = config.dotfiles.locale.defaultLocale;
    i18n.extraLocaleSettings =
      let extra = config.dotfiles.locale.extraLocale;
      in {
        LC_ADDRESS = extra;
        LC_IDENTIFICATION = extra;
        LC_MEASUREMENT = extra;
        LC_MONETARY = extra;
        LC_NAME = extra;
        LC_NUMERIC = extra;
        LC_PAPER = extra;
        LC_TIME = extra;
        LC_TELEPHONE = extra;
      };

    users.users.${config.dotfiles.user.name} = {
      isNormalUser = true;
      extraGroups = [ "networkmanager" ] ++ lib.optionals config.dotfiles.user.wheel [ "wheel" ];
    };

    services.xserver.xkb = {
      layout = config.dotfiles.locale.xkbLayout;
      variant = config.dotfiles.locale.xkbVariant;
    };
    console.keyMap = config.dotfiles.locale.keyMap;

    hardware.enableAllFirmware = true;

    environment.systemPackages = with pkgs; [
      vim
      tree
      wget
      htop
      btop
      dig
      killall
      unixtools.ifconfig
      unzip
      zip
      udisks

      # python312

      git
      home-manager

      age
      sops

      kitty.terminfo

      gemini-cli
      claude-code
    ];

    nix.settings.experimental-features = [ "nix-command" "flakes" ];

    system.stateVersion = "23.11";

    documentation.nixos.enable = false;
    documentation.man.enable = false;

    home-manager.useGlobalPkgs = true;
    home-manager.useUserPackages = true;
    home-manager.backupFileExtension = "backup";

    home-manager.users.${config.dotfiles.user.name} = { osConfig, ... }: {
      home.username = osConfig.dotfiles.user.name;
      home.homeDirectory = "/home/${osConfig.dotfiles.user.name}";
      home.stateVersion = "23.11";
    };
  };
}
