{ lib, pkgs, nixosConfig, ... }:
let
  username = "simon";
in {
  imports = [
		./programs/git.nix
  ];

  programs.neovim.enable = lib.mkIf nixosConfig.dotfiles.programs.neovim.enable true;
  xdg.configFile."nvim" = lib.mkIf nixosConfig.dotfiles.programs.neovim.enable {
    source = ./nvim;
  };

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
