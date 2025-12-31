{ pkgs, ... }:
{
	home.packages = with pkgs; [
		streamcontroller
	];
}
