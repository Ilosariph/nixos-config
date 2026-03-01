{ lib, config, ... }:
{
  config = lib.mkIf config.dotfiles.bluetooth.enable {
    hardware.bluetooth.enable = true;
  };
}
