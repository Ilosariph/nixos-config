{ inputs, ... }: {
  # finix counterpart of modules/packages/base/base.nix
  flake.finixModules.base = { config, pkgs, lib, modules, ... }:
    let
      user = config.dotfiles.user.name;
      extra = config.dotfiles.locale.extraLocale;
    in {
      imports = [
        inputs.hjem.finixModules.default
        modules.nix-daemon
        modules.sudo
        modules.polkit
        modules.sysklogd
        modules.getty
        modules.bash
        modules.cron
        modules.chronyd
      ];

      finit.runlevel = 3;

      time.timeZone = config.dotfiles.locale.timeZone;

      i18n.defaultLocale = config.dotfiles.locale.defaultLocale;
      i18n.extraLocaleSettings = {
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

      hardware.console.keyMap = config.dotfiles.locale.keyMap;

      # NixOS services.xserver.xkb.extraLayouts rebuilds xkeyboard-config;
      # libxkbcommon also reads /etc/xkb (its extra path), which is enough for
      # Wayland compositors.
      environment.etc."xkb/symbols/ch-nodead-cflex".text = ''
        default partial alphanumeric_keys
        xkb_symbols "basic" {
          include "ch(de)"
          key <AE12> { [ asciicircum, grave, asciitilde ] };
        };
      '';

      users.users.${user} = {
        isNormalUser = true;
        extraGroups = [ "networkmanager" "video" "input" "audio" ]
          ++ lib.optionals config.dotfiles.user.wheel [ "wheel" ];
      };

      users.users.root.password = "!";

      # eudev + elogind: closest to NixOS (polkit active sessions, udisks2,
      # libinput, steam/flatpak all expect logind + libudev)
      services.udev.enable = true;
      services.elogind.enable = true;
      services.dbus.enable = true;
      services.polkit.enable = true;
      services.sysklogd.enable = true;
      services.getty.enable = true;
      services.chrony.enable = true;
      services.cron.enable = true;

      programs.sudo.enable = true;
      programs.bash.enable = true;

      # Same kernel selection + C++17 stdenv tweak as the NixOS base aspect
      # (yeetmouse's GUI needs -std=c++17 under gcc 16).
      boot.kernelPackages = lib.mkIf (config.dotfiles.kernel != "none") (
        (
          {
            default = pkgs.linuxPackages_latest;
            stable = pkgs.linuxPackages_6_6;
            gaming = pkgs.linuxPackages_xanmod_latest;
          }.${config.dotfiles.kernel}
        ).extend (_: kprev: {
          stdenv = pkgs.stdenvAdapters.overrideMkDerivationArgs (args: {
            env = (args.env or { }) // {
              NIX_CXXSTDLIB_COMPILE =
                (args.env.NIX_CXXSTDLIB_COMPILE or "") + " -std=c++17";
            };
          }) kprev.stdenv;
        })
      );

      boot.kernelModules = lib.mkIf (config.dotfiles.kernel == "gaming") [ "ntsync" ];

      services.udev.extraRules = lib.mkIf (config.dotfiles.kernel == "gaming") ''
        KERNEL=="ntsync", GROUP="users", MODE="0660"
      '';

      security.pam.environment.PROTON_USE_NTSYNC = lib.mkIf (config.dotfiles.kernel == "gaming") {
        default = "1";
      };

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

        git

        age
        sops

        kitty.terminfo

        claude-code
        uv

        comma
        iputils
        iproute2
        pciutils
        usbutils
      ];

      services.nix-daemon = {
        enable = true;
        settings = {
          experimental-features = [ "nix-command" "flakes" ];
          trusted-users = [ "root" "@wheel" ];
        };
      };

      environment.etc."machine-name".text = config.networking.hostName + "\n";

      # Hjem replaces home-manager: it only links files, there are no user
      # services. Long-running user programs are started from the compositor
      # autostart instead (see the umbriel aspect).
      hjem.clobberByDefault = true;
      hjem.users.${user} = {
        enable = true;
        user = user;
        directory = "/home/${user}";
      };
    };
}
