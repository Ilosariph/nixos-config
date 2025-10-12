{ lib, pkgs, ... };
{
  home = {
    packages = with pkgs; [
      hello
    ];

    username = "simon";
    homeDirectory = "/home/simon";

    stateVersion = "23.11";
  };
}
