{ config, pkgs, pkgs-unstable, hyprland, ... }:
{
  imports = [
		./network.nix
  ];

  time.timeZone = "Europe/Zurich";

  i18n.defaultLocale = "en_US.UTF-8";
  i18n.extraLocaleSettings = {
    LC_ADDRESS = "de_CH.UTF-8";
    LC_IDENTIFICATION = "de_CH.UTF-8";
    LC_MEASUREMENT = "de_CH.UTF-8";
    LC_MONETARY = "de_CH.UTF-8";
    LC_NAME = "de_CH.UTF-8";
    LC_NUMERIC = "de_CH.UTF-8";
    LC_PAPER = "de_CH.UTF-8";
    LC_TELEPHONE = "de_CH.UTF-8";
    LC_TIME = "de_CH.UTF-8";
  };

  users.users.simon = {
    isNormalUser = true;
    description = "simon";
  };

  hardware.enableAllFirmware = true;

  environment.systemPackages = with pkgs; [
		vim
		tree
		wget
		htop
		dig
		killall
		git
		age
		sops
  ];

  virtualisation.docker.enable = true;
  programs._1password.enable = true;

  nix.settings.experimental-features = [ "nix-command" "flakes" ];
}
