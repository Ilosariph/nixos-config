{ lib, config, ... }:
{
  config = lib.mkIf (config.dotfiles.hyprland.statusbar == "noctalia") {
    services.power-profiles-daemon.enable = true;
    services.upower.enable = true;
  };
}
