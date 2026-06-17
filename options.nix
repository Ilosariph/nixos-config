{ lib, config, ... }:
{
  options.dotfiles = {
    desktop = {
      enable = lib.mkOption {
        type = lib.types.bool;
        default = false;
        description = "Enable desktop environment (audio, printing, flatpak, GUI programs, window manager).";
      };
    };

    user = {
      name = lib.mkOption {
        type = lib.types.str;
        default = "simon";
        description = "Primary user account name.";
      };
      wheel = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = "Add primary user to the wheel group (sudo access).";
      };
    };

    windowManager = {
      type = lib.mkOption {
        type = lib.types.enum [ "hyprland" "niri" ];
        default = "hyprland";
        description = "Window manager to use on desktop systems.";
      };
      mainMonitor = lib.mkOption {
        type = lib.types.str;
        default = "";
        description = "The primary monitor name (used for screen locking widgets, default workspace assignment, etc.).";
      };
      displayManager = lib.mkOption {
        type = lib.types.enum [ "gdm" "sddm" "lightdm" "greetd" ];
        default = "gdm";
        description = "Display manager / login screen to use.";
      };
      statusbar = lib.mkOption {
        type = lib.types.enum [ "waybar" "noctalia" ];
        default = "waybar";
        description = "Statusbar/shell to use (waybar with mako, or noctalia-shell with built-in notifications).";
      };
      keyboardLayout = lib.mkOption {
        type = lib.types.enum [ "qwerty" "colemak" ];
        default = "qwerty";
        description = "Keyboard layout for window manager keybindings.";
      };
      settings = {
        monitors = lib.mkOption {
          type = lib.types.listOf lib.types.str;
          default = [];
          description = "A list of monitor configurations for the window manager.";
        };
        workspaces = lib.mkOption {
          type = lib.types.listOf lib.types.str;
          default = [];
          description = "A list of workspace configurations for the window manager.";
        };
        left = lib.mkOption {
          type = lib.types.str;
          default = if config.dotfiles.windowManager.keyboardLayout == "qwerty" then "H" else "N";
          description = "Keybinding for left.";
        };
        right = lib.mkOption {
          type = lib.types.str;
          default = if config.dotfiles.windowManager.keyboardLayout == "qwerty" then "L" else "I";
          description = "Keybinding for right.";
        };
        up = lib.mkOption {
          type = lib.types.str;
          default = if config.dotfiles.windowManager.keyboardLayout == "qwerty" then "K" else "U";
          description = "Keybinding for up.";
        };
        down = lib.mkOption {
          type = lib.types.str;
          default = if config.dotfiles.windowManager.keyboardLayout == "qwerty" then "J" else "comma";
          description = "Keybinding for down.";
        };
        execOnce = lib.mkOption {
          type = lib.types.listOf lib.types.str;
          default = [];
          description = "Extra commands to run once on window manager startup (appended to the shared exec-once list).";
        };
      };
    };

    services = {
      pangolinNewt = {
        enable = lib.mkOption {
          type = lib.types.bool;
          default = false;
          description = "Enable Pangolin Newt tunnel client (fosrl-newt).";
        };
        endpoint = lib.mkOption {
          type = lib.types.str;
          default = "";
          description = "Pangolin server endpoint URL (e.g. 'https://pangolin.example.com').";
        };
        idSecret = lib.mkOption {
          type = lib.types.str;
          default = "newt-id";
          description = "Name of the sops secret containing the Newt ID.";
        };
        secretSecret = lib.mkOption {
          type = lib.types.str;
          default = "newt-secret";
          description = "Name of the sops secret containing the Newt secret.";
        };
      };
      ssh = {
        enable = lib.mkOption {
          type = lib.types.bool;
          default = false;
          description = "Enable OpenSSH daemon.";
        };
        authorizedKeySecret = lib.mkOption {
          type = lib.types.nullOr lib.types.str;
          default = null;
          description = "Name of the sops secret to use as authorized_keys (e.g. 'nucserver-ssh-public-key').";
        };
      };
      fail2ban = {
        enable = lib.mkOption {
          type = lib.types.bool;
          default = false;
          description = "Enable fail2ban intrusion prevention.";
        };
      };
      backup = {
        enable = lib.mkOption {
          type = lib.types.bool;
          default = false;
          description = "Enable the generic backup service.";
        };
        jobs = lib.mkOption {
          type = lib.types.listOf (lib.types.submodule {
            options = {
              name = lib.mkOption {
                type = lib.types.str;
                description = "Unique job identifier, used for systemd unit names (backup-<name>).";
              };
              source = lib.mkOption {
                type = lib.types.str;
                description = "Source path to back up.";
              };
              destination = lib.mkOption {
                type = lib.types.str;
                description = "Destination path for the backup.";
              };
              calendar = lib.mkOption {
                type = lib.types.str;
                default = "*-*-* 03:00:00";
                description = "systemd OnCalendar expression controlling when the job runs (e.g. '*-*-* 03:00:00', 'weekly').";
              };
              mode = lib.mkOption {
                type = lib.types.enum [ "sync" "snapshot" ];
                default = "sync";
                description = "sync: rsync --delete to destination. snapshot: creates a dated subfolder per run.";
              };
              keep = lib.mkOption {
                type = lib.types.nullOr lib.types.int;
                default = null;
                description = "snapshot mode only: number of most recent snapshots to retain. null = keep all.";
              };
            };
          });
          default = [];
          description = "List of backup jobs to run.";
        };
      };
      jellyfin = {
        enable = lib.mkOption {
          type = lib.types.bool;
          default = false;
          description = "Enable Jellyfin media server container.";
        };
        publishedServerUrl = lib.mkOption {
          type = lib.types.str;
          default = "";
          description = "Published server URL for Jellyfin autodiscovery (JELLYFIN_PublishedServerUrl).";
        };
      };
    };

    vpn = {
      enable = lib.mkOption {
        type = lib.types.bool;
        default = false;
        description = "Enable VPN.";
      };
      accounts = lib.mkOption {
        type = lib.types.listOf lib.types.str;
        default = [];
        description = "List of VPN accounts to import (e.g. ['home', 'proton']).";
      };
    };
    bluetooth = {
      enable = lib.mkOption {
        type = lib.types.bool;
        default = false;
        description = "Enable bluetooth.";
      };
    };
    wallpapers = {
      directory = lib.mkOption {
        type = lib.types.path;
        default = ./modules/packages/wallpapers/wallpapers;
        description = ''
          Directory containing wallpaper image files. Imported into the nix store
          so all consumers (hyprpaper, noctalia, the random-wallpaper script, etc.)
          read from the same store path.
        '';
      };
    };
    security = {
      yubikey = {
        enable = lib.mkOption {
          type = lib.types.bool;
          default = false;
          description = "Enable YubiKey support (management tools, udev rules, pcscd).";
        };
        luks = {
          enable = lib.mkOption {
            type = lib.types.bool;
            default = false;
            description = ''
              Enable YubiKey FIDO2 LUKS disk unlocking via systemd stage-1 initrd.
              Requires LUKS2 (not LUKS1). The partition must already be LUKS2-formatted
              with a password slot before enrolling keys.

              After enabling and rebuilding, enroll each YubiKey (swap physical key between runs):
                systemd-cryptenroll --fido2-device=auto /dev/<partition>   # key 1
                systemd-cryptenroll --fido2-device=auto /dev/<partition>   # key 2
                systemd-cryptenroll --fido2-device=auto /dev/<partition>   # key 3

              List enrolled tokens and their slot numbers:
                systemd-cryptenroll /dev/<partition>

              Remove a specific key by its LUKS keyslot number:
                systemd-cryptenroll --wipe-slot=<N> /dev/<partition>

              The FIDO2 metadata is stored in the LUKS2 header; no extra NixOS device
              config is needed — just add the partition to boot.initrd.luks.devices
              in hardware-configuration.nix as normal.
            '';
          };
        };
        sudo = {
          enable = lib.mkOption {
            type = lib.types.bool;
            default = false;
            description = ''
              Enable YubiKey (FIDO2/U2F) as an alternative to password for sudo.
              Login authentication is unaffected.

              After enabling, register the YubiKey:
                pamu2fcfg -u <username> | sudo tee -a /etc/u2f_keys
                (touch the YubiKey when prompted)

              To remove a key, edit /etc/u2f_keys and delete the line for the user.
              To register a second key, run pamu2fcfg -n then append its output.
            '';
          };
        };
        systemAuth = {
          enable = lib.mkOption {
            type = lib.types.bool;
            default = false;
            description = ''
              Enable YubiKey (FIDO2/U2F) as an alternative to password for polkit
              system-authentication prompts (e.g. 1Password re-auth, any privilege dialog).
              Login and screen-unlock are unaffected.

              Requires dotfiles.security.yubikey.sudo.enable = true (key registration
              and the pam_u2f module are shared — same /etc/u2f_keys file).
            '';
          };
        };
      };
    };

    bootloader = {
      type = lib.mkOption {
        type = lib.types.enum [ "systemd" "grub" ];
        default = "systemd";
        description = "Bootloader to use.";
      };
      grubDevice = lib.mkOption {
        type = lib.types.str;
        default = "/dev/sda";
        description = "Device to install GRUB to.";
      };
    };
    programs = {
      _1password = {
        enable = lib.mkOption {
          type = lib.types.bool;
          default = config.dotfiles.desktop.enable;
          description = "Enable 1Password CLI and GUI integration.";
        };
        sshAgent = lib.mkOption {
          type = lib.types.bool;
          default = true;
          description = "Use 1Password SSH agent. Set to false on servers to use forwarded agent.";
        };
      };
      docker = {
        enable = lib.mkOption {
          type = lib.types.bool;
          default = true;
          description = "Enable Docker virtualisation.";
        };
        basePath = lib.mkOption {
          type = lib.types.str;
          default = "/home/simon/docker";
          description = "Base directory for Docker container data volumes.";
        };
      };
      virtualisation = {
        enable = lib.mkOption {
          type = lib.types.bool;
          default = config.dotfiles.desktop.enable;
          description = "Enable libvirt/QEMU virtualisation (virt-manager).";
        };
      };
      neovim = {
        enable = lib.mkOption {
          type = lib.types.bool;
          default = true;
          description = "Enable neovim with dotfiles configuration.";
        };
      };

      # Terminal & Shell
      kitty = {
        enable = lib.mkOption {
          type = lib.types.bool;
          default = config.dotfiles.desktop.enable;
          description = "Enable kitty terminal emulator.";
        };
      };
      fish = {
        enable = lib.mkOption {
          type = lib.types.bool;
          default = true;
          description = "Enable fish shell configuration.";
        };
      };
      bash = {
        enable = lib.mkOption {
          type = lib.types.bool;
          default = true;
          description = "Enable bash shell configuration.";
        };
      };
      tmux = {
        enable = lib.mkOption {
          type = lib.types.bool;
          default = true;
          description = "Enable tmux terminal multiplexer configuration.";
        };
      };

      # Media
      mpv = {
        enable = lib.mkOption {
          type = lib.types.bool;
          default = config.dotfiles.desktop.enable;
          description = "Enable mpv media player.";
        };
      };
      yazi = {
        enable = lib.mkOption {
          type = lib.types.bool;
          default = config.dotfiles.desktop.enable;
          description = "Enable yazi file manager.";
        };
      };

      # Utilities
      swappy = {
        enable = lib.mkOption {
          type = lib.types.bool;
          default = config.dotfiles.desktop.enable;
          description = "Enable swappy screenshot annotation tool.";
        };
      };
      udiskie = {
        enable = lib.mkOption {
          type = lib.types.bool;
          default = config.dotfiles.desktop.enable;
          description = "Enable udiskie USB automounter.";
        };
      };
      zed = {
        enable = lib.mkOption {
          type = lib.types.bool;
          default = config.dotfiles.desktop.enable;
          description = "Enable Zed text editor.";
        };
      };

      # Specialized
      orca-slicer = {
        enable = lib.mkOption {
          type = lib.types.bool;
          default = config.dotfiles.desktop.enable;
          description = "Enable OrcaSlicer 3D printer slicer.";
        };
      };
      vr = {
        enable = lib.mkOption {
          type = lib.types.bool;
          default = false;
          description = "Enable VR support (WiVRn / WayVR). Requires nixpkgs-xr.";
        };
      };
      thonny = {
        enable = lib.mkOption {
          type = lib.types.bool;
          default = false;
          description = "Enable Thonny Python IDE (includes dialout group for MicroPython board access).";
        };
      };
      steam = {
        enable = lib.mkOption {
          type = lib.types.bool;
          default = false;
          description = "Enable Steam gaming platform.";
        };
      };
      blog = {
        enable = lib.mkOption {
          type = lib.types.bool;
          default = false;
          description = "Enable Hugo blog development environment (hugo + direnv shell in ~/blog).";
        };
      };
      yeetmouse = {
        enable = lib.mkOption {
          type = lib.types.bool;
          default = false;
          description = "Enable YeetMouse kernel-level mouse acceleration (compositor-agnostic).";
        };
      };
    };
    audio = {
      routing = lib.mkOption {
        type = lib.types.enum [ "pipewire-virtual" "pulsemeeter" "none" ];
        default = "none";
        description = ''
          Audio routing mode.
          pipewire-virtual: three PipeWire null sinks (apps/music/comms) looped back to the
            physical output, with WirePlumber rules auto-routing apps to their sink.
          pulsemeeter: install pulsemeeter + qpwgraph for manual GUI routing.
          none: no routing tools installed.
        '';
      };
      easyeffects = {
        enable = lib.mkOption {
          type = lib.types.bool;
          default = false;
          description = "Enable EasyEffects audio processor. Enabled automatically by the audio-routing module for pipewire-virtual and pulsemeeter modes.";
        };
      };
      outputSink = lib.mkOption {
        type = lib.types.str;
        default = "";
        description = ''
          PipeWire node name of the physical output sink the virtual loopbacks route into
          (e.g. "alsa_output.usb-Focusrite_Scarlett_2i2_USB_..."). Run
          `pw-cli ls Node | grep alsa_output` to find the exact name.
          Leave empty to fall back to WirePlumber's default output selection.
        '';
      };
      volumeLimit = lib.mkOption {
        type = lib.types.float;
        default = 1.0;
        # set to 1.5 for 150% — raises the ceiling exposed through the PulseAudio compat layer
        description = "Maximum volume scalar exposed through the PulseAudio compat layer. 1.0 = 100%, 1.5 = 150%.";
      };
    };

    locale = {
      timeZone = lib.mkOption {
        type = lib.types.str;
        default = "Europe/Zurich";
        description = "System time zone.";
      };
      defaultLocale = lib.mkOption {
        type = lib.types.str;
        default = "en_US.UTF-8";
        description = "Default system locale.";
      };
      extraLocale = lib.mkOption {
        type = lib.types.str;
        default = "de_CH.UTF-8";
        description = "Locale used for LC_ADDRESS, LC_MEASUREMENT, LC_TIME, etc.";
      };
      keyMap = lib.mkOption {
        type = lib.types.str;
        default = "sg";
        description = "Console key map.";
      };
      xkbLayout = lib.mkOption {
        type = lib.types.str;
        default = "ch";
        description = "X keyboard layout.";
      };
      xkbVariant = lib.mkOption {
        type = lib.types.str;
        default = "";
        description = "X keyboard variant.";
      };
    };
    direnv = {
      shells = lib.mkOption {
        type = lib.types.listOf (lib.types.submodule {
          options = {
            dir = lib.mkOption {
              type = lib.types.str;
              description = "Directory relative to home to set up the direnv shell in (e.g. 'blog').";
            };
            packages = lib.mkOption {
              type = lib.types.listOf lib.types.package;
              default = [];
              description = "Packages to make available in the shell (used when shellFile is null).";
            };
            shellFile = lib.mkOption {
              type = lib.types.nullOr lib.types.path;
              default = null;
              description = "Path to a shell.nix to use directly instead of generating one from packages.";
            };
          };
        });
        default = [];
        description = "List of directories to set up nix-direnv shells in.";
      };
    };

    sharesDefaultServer = lib.mkOption {
      type = lib.types.str;
      default = "192.168.1.148";
      description = "Default SMB server IP used when a share does not specify its own server.";
    };

    shares = lib.mkOption {
      type = lib.types.listOf (lib.types.submodule ({ config, ... }: {
        options = {
          mountPoint = lib.mkOption {
            type = lib.types.str;
            description = "Local mount point (e.g. '/mnt/projects').";
          };
          server = lib.mkOption {
            type = lib.types.nullOr lib.types.str;
            default = null;
            description = "SMB server IP. Defaults to dotfiles.sharesDefaultServer when null.";
          };
          share = lib.mkOption {
            type = lib.types.str;
            description = "Share name on the server (e.g. 'p' or 'simon_data').";
          };
          credentials = lib.mkOption {
            type = lib.types.str;
            description = "Path to the credentials file (e.g. '/etc/nixos/smb-p').";
          };
          uid = lib.mkOption {
            type = lib.types.int;
            default = 1000;
            description = "UID for the mount owner.";
          };
          gid = lib.mkOption {
            type = lib.types.int;
            default = 100;
            description = "GID for the mount owner.";
          };
        };
      }));
      default = [];
      description = "List of CIFS/SMB shares to mount.";
    };

    sops = {
      enable = lib.mkOption {
        type = lib.types.bool;
        default = false;
        description = "Enable sops-nix secret decryption.";
      };
      ageKeyFile = lib.mkOption {
        type = lib.types.str;
        default = "/home/${config.dotfiles.user.name}/.config/sops/age/keys.txt";
        description = "Path to the age private key file used to decrypt sops secrets.";
      };
      defaultSecretsFile = lib.mkOption {
        type = lib.types.path;
        description = "Default sops secrets file. Must be set to the absolute path of secrets.yaml in the flake.";
      };
    };

    kernel = lib.mkOption {
      type = lib.types.enum [ "default" "stable" "gaming" "none" ];
      default = "default";
      description = ''
        Kernel variant to use.
        default: linuxPackages_latest (upstream latest)
        stable: linuxPackages_6_6 (6.6 LTS, for servers)
        gaming: linuxPackages_xanmod_latest (XanMod gaming kernel)
        none: do not set boot.kernelPackages (for machines with special kernels, e.g. macbook)
      '';
    };

    deploy = {
      target = {
        enable = lib.mkOption {
          type = lib.types.bool;
          default = false;
          description = "Include this machine as a deploy-rs target in the flake output.";
        };
        user = lib.mkOption {
          type = lib.types.str;
          default = config.dotfiles.user.name;
          description = "User that the deployed profile activates as. Defaults to dotfiles.user.name.";
        };
        sshUser = lib.mkOption {
          type = lib.types.nullOr lib.types.str;
          default = null;
          description = "SSH user for connecting. Defaults to target.user when null.";
        };
        hostname = lib.mkOption {
          type = lib.types.nullOr lib.types.str;
          default = null;
          description = "Hostname or IP for deploy-rs. When null, derived from dotfiles.network.staticIP or dotfiles.network.hostname.";
        };
        remoteBuild = lib.mkOption {
          type = lib.types.bool;
          default = false;
          description = "Build the system on the remote machine instead of pushing from the deploying machine.";
        };
        trustedPublicKeySecret = lib.mkOption {
          type = lib.types.nullOr lib.types.str;
          default = null;
          description = "Name of the sops secret containing the deploying machine's nix store public key. Loaded and added to nix.settings.trusted-public-keys at activation time.";
        };
      };
      deployer = {
        installTool = lib.mkOption {
          type = lib.types.bool;
          default = false;
          description = "Install the deploy-rs binary on this machine (set on the deploying machine, e.g. mainpc).";
        };
        signingKeySecret = lib.mkOption {
          type = lib.types.nullOr lib.types.str;
          default = null;
          description = "Name of the sops secret containing the nix store private signing key. Set on the deploying machine to sign store paths before pushing.";
        };
      };
    };

    network = {
      wakeOnLan = lib.mkOption {
        type = lib.types.bool;
        default = false;
        description = "Enable Wake-on-LAN on the network interface.";
      };
      hostname = lib.mkOption {
        type = lib.types.nullOr lib.types.str;
        default = null;
        description = "Hostname for the machine. Defaults to 'nixos-{pc}' if null.";
      };
      interface = lib.mkOption {
        type = lib.types.nullOr lib.types.str;
        default = null;
        description = "Network interface name for static IP (e.g. 'enp3s0'). Required when staticIP is set.";
      };
      staticIP = lib.mkOption {
        type = lib.types.nullOr lib.types.str;
        default = null;
        description = "Static IPv4 address in CIDR notation (e.g. '192.168.1.10/24'). Requires interface to be set.";
      };
      gateway = lib.mkOption {
        type = lib.types.nullOr lib.types.str;
        default = null;
        description = "Default gateway IP. Required when staticIP is set.";
      };
      nameservers = lib.mkOption {
        type = lib.types.listOf lib.types.str;
        default = [
          "192.168.1.148"
          "fd32:9975:719f:0:7a55:36ff:fe02:15f3"
          "1.1.1.1"
          "2606:4700:4700::1111"
          "1.0.0.1"
          "2606:4700:4700::1001"
        ];
        description = "DNS nameservers.";
      };
    };
  };
}
