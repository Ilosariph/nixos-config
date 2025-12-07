{ lib, pkgs, pkgs-stable, config, walker, ... }: 
let
  username = "simon";
in {
  imports = [
	./programs/git.nix
  ];

  home = {
    inherit username;
    homeDirectory = "/home/${username}";

    packages = with pkgs; [
	  unzip
	  python312
	  zip
	  udisks
    ];

    stateVersion = "23.11";
  };
}
