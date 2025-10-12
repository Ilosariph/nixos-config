{ lib, pkgs, ... }:
let
  username = "simon";
in {
  home = {
    packages = with pkgs; [
      cowsay lolcat
    ];

    inherit username;
    homeDirectory = "/home/${username}";

    stateVersion = "23.11";
  };
}
