{ config, pkgs, ... }:
{
  home.packages = [
    pkgs.wlx-overlay-s
  ];
  xdg.configFile."wlxoverlay/openxr_actions.json5" = {
    source = ./openxr_actions.json5; 
  };
}
