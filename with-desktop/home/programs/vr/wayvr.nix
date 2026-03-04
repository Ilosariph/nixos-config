{ config, pkgs, ... }:
{
  home.packages = [
    pkgs.wayvr
  ];
  xdg.configFile."wlxoverlay/openxr_actions.json5" = {
    source = ./openxr_actions.json5;
  };
}
