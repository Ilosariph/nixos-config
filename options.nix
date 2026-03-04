{ lib, config, ... }:
{
  options.dotfiles = {
    windowManager = {
      mainMonitor = lib.mkOption {
        type = lib.types.str;
        default = "";
        description = "The primary monitor name (used for screen locking widgets, default workspace assignment, etc.).";
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
        sensitivity = lib.mkOption {
          type = lib.types.nullOr lib.types.float;
          default = null;
          description = "Mouse sensitivity.";
        };
        accel_profile = lib.mkOption {
          type = lib.types.nullOr lib.types.str;
          default = null;
          description = "Mouse acceleration profile.";
        };
        execOnce = lib.mkOption {
          type = lib.types.listOf lib.types.str;
          default = [];
          description = "Extra commands to run once on window manager startup (appended to the shared exec-once list).";
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
    bootloader = lib.mkOption {
      type = lib.types.enum [ "systemd" "grub" ];
      default = "systemd";
      description = "Bootloader to use.";
    };
    grubDevice = lib.mkOption {
      type = lib.types.str;
      default = "/dev/sda";
      description = "Device to install GRUB to.";
    };
    use1PasswordAgent = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Use 1Password SSH agent. Set to false on servers to use forwarded agent.";
    };
  };
}
