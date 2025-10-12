{ lib, pkgs, ... }: 
let
  username = "simon";
in {
  imports = [
    ./hypr/hyprland.nix
    ./hypr/hyprlock.nix
  ];

  home = {
    inherit username;
    homeDirectory = "/home/${username}";

    programs.neovim.enable = true;
    xdg.configFile."nvim".source = ./nvim;

    packages = with pkgs; [
      kdePackages.dolphin
      hyprshot
      discord
      grayjay
    ];

    sessionVariables = {
      XDG_THEME_MODE = "dark";
    };

    stateVersion = "23.11";
  };
}
