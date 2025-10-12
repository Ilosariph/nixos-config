{ lib, pkgs, ... }: 
let
  username = "simon";
in {
  imports = [
    ./hyprland.nix
    ./hyprlock.nix
  ];

  home = {
    inherit username;
    homeDirectory = "/home/${username}";
    packages = with pkgs; [
    # packages for user
      kdePackages.dolphin
      hyprshot
      discord
    ];

    stateVersion = "23.11";
  };
}
