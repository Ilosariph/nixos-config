{ pkgs, config, ... }:
{
  imports = [
    ./ollama.nix
  ];

  users.users.${config.dotfiles.user.name}.extraGroups = [ "docker" ];

  environment.sessionVariables = {
    OLLAMA_HOST = "http://127.0.0.1:11435";
    OLLAMA_MODELS = "/var/lib/ollama/models";
  };

  environment.systemPackages = with pkgs; [
    nodejs_22
  ];

	hardware.graphics.enable = true;

	# Enable ROCm support for AMD GPUs
	systemd.tmpfiles.rules = [
	  "L+    /opt/rocm/hip   -    -    -     -    ${pkgs.rocmPackages.clr}"
	];

	hardware.graphics.extraPackages = with pkgs; [
	  rocmPackages.clr.icd
	];

	# Ollama port for nanobot
	networking.firewall.interfaces.docker0.allowedTCPPorts = [ 3001 ];
}
