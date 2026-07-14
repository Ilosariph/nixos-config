{ pkgs, config, ... }:
{
  imports = [
    ./ollama.nix
  ];

  users.users.${config.dotfiles.user.name}.extraGroups = [ "docker" ];

  environment.systemPackages = with pkgs; [
    nodejs_22
    rocmPackages.rocminfo
    rocmPackages.rocm-smi
  ];

  boot.kernel.sysctl = {
    "vm.max_map_count" = 1048576;
    "vm.swappiness" = 10;
  };

  hardware.graphics.enable = true;

	# Enable ROCm support for AMD GPUs
	systemd.tmpfiles.rules = [
	  "L+    /opt/rocm/hip   -    -    -     -    ${pkgs.rocmPackages.clr}"
	];

	hardware.graphics.extraPackages = with pkgs; [
	  rocmPackages.clr.icd
	];
}
