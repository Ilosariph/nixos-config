{ lib, pkgs, config, ... }:
{
  dotfiles.kernel = "none";
  dotfiles.asahiFairydust.enable = true;
  dotfiles.sops.enable = true;
  dotfiles.sops.host = "macbook";
  dotfiles.desktop.enable = true;
  dotfiles.programs.tmux.enable = false;
  dotfiles.programs.gnirehtet.enable = true;
  dotfiles.windowManager.type = "umbriel";
  dotfiles.bluetooth.enable = true;
  dotfiles.windowManager.mainMonitor = "eDP-1";
	dotfiles.windowManager.statusbar = "noctalia";
  dotfiles.vpn = {
    enable = true;
    accounts = [ "home" "proton" ];
  };
  dotfiles.programs.virtualisation.enable = false;
  dotfiles.windowManager.settings = {
    monitors = [
      "eDP-1, 2560x1600@60.00000, 0x0, 1.3333334"
    ];
  };
  dotfiles.shares = [
    {
      mountPoint = "/mnt/simon";
      share = "simon_data";
      credentials = "/etc/nixos/smb-s";
    }
  ];
  dotfiles.direnv.shells = let
    shellsDir = config.dotfiles.direnv.shellsDir;
  in [
    {
      dir = "Projects";
      shellFile = shellsDir + "/python312.nix";
    }
    {
      dir = "Projects/touchbar";
      shellFile = shellsDir + "/touchbar.nix";
    }
    {
      dir = "Projects/nonogram";
      shellFile = shellsDir + "/nonogram.nix";
    }
    {
      dir = "Projects/sudoku";
      shellFile = shellsDir + "/sudoku.nix";
    }
  ];
}
