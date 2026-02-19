{ lib, pkgs, pkgs-stable, config, ... }:
{
  home = {
    packages = with pkgs; [
			tmux
		];
	};
}