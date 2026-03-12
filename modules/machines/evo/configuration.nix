{ pkgs, config, ... }:
{
  imports = [
    ./ollama.nix
  ];

	hardware.graphics.enable = true;

	# Enable ROCm support for AMD GPUs
	systemd.tmpfiles.rules = [
	  "L+    /opt/rocm/hip   -    -    -     -    ${pkgs.rocmPackages.clr}"
	];

	hardware.graphics.extraPackages = with pkgs; [
	  rocmPackages.clr.icd
	];

}
