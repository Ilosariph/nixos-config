{ pkgs, config, ... }:
{
  imports = [
    ../general/ssh/ssh-with-nucserver-key.nix
    ./shares.nix
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


	services.pangolin = {
    enable = true;
    baseDomain = "pangolin.local"; 
    letsEncryptEmail = "non@existent.ch";
    environmentFile = "/etc/nixos/secrets/pangolin.env";
    openFirewall = true;
  };
}
