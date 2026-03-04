{ lib, config, ... }:
{
  config = lib.mkIf (config.dotfiles.windowManager.statusbar == "noctalia") {
    services.power-profiles-daemon.enable = true;
    services.upower.enable = true;
  };
}
