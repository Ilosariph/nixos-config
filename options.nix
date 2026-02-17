{ lib, ... }:
{
  options.dotfiles = {
    hyprland = {
      settings = {
        monitors = lib.mkOption {
          type = lib.types.listOf lib.types.str;
          default = [];
          description = "A list of monitor configurations for Hyprland.";
        };
        left = lib.mkOption {
          type = lib.types.str;
          default = "H";
          description = "Keybinding for left.";
        };
        right = lib.mkOption {
          type = lib.types.str;
          default = "L";
          description = "Keybinding for right.";
        };
        up = lib.mkOption {
          type = lib.types.str;
          default = "K";
          description = "Keybinding for up.";
        };
        down = lib.mkOption {
          type = lib.types.str;
          default = "J";
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
      };
    };
    vpn = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Enable VPN.";
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
  };
}
