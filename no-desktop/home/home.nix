{ lib, pkgs, pkgs-stable, config, dms, ... }: 
{
  home = {
    packages = with pkgs; [
			tmux
		];
	};
}
