{ config, ... }:
{
  dotfiles.sops.enable = true;
  dotfiles.sops.host = "evo";
  dotfiles.deploy.target.enable = true;
  dotfiles.deploy.target.trustedPublicKeys = [ config.dotfiles.private.nix.mainpcSigningPublicKey ];
  dotfiles.kernel = "default";
  dotfiles.bootloader.type = "systemd";
  dotfiles.programs._1password.sshAgent = false;
  dotfiles.services.ssh.enable = true;
  dotfiles.services.ssh.authorizedKeys = config.dotfiles.private.ssh.authorizedKeys;
  dotfiles.services.jellyfin = {
		enable = true;
		publishedServerUrl = "https://${config.dotfiles.private.domains.jellyfin}";
	};
  dotfiles.services.fail2ban.enable = true;
  dotfiles.services.hermes.enable = true;
  dotfiles.services.nixEval.enable = true;
  dotfiles.services.backup.enable = true;
  dotfiles.services.backup.jobs = [
    {
      name = "docker-configs";
      source = "/home/simon/docker/";
      destination = "/mnt/docker-backup/evo";
      calendar = "*-*-* 03:00:00";
      mode = "snapshot";
      keep = 3;
    }
  ];
  dotfiles.services.pangolinNewt = {
    enable = true;
    endpoint = "https://${config.dotfiles.private.domains.pangolin}";
    idSecret = "evo-newt-id";
    secretSecret = "evo-newt-secret";
  };
  dotfiles.shares = [
    {
      mountPoint = "/mnt/projects";
      share = "p";
      credentials = "/etc/nixos/smb-p";
    }
    {
      mountPoint = "/mnt/arr";
      share = "arr";
      credentials = "/etc/nixos/smb-arr";
    }
    {
      mountPoint = "/mnt/docker-backup";
      share = "docker-backup";
      credentials = "/etc/nixos/smb-docker-backup";
    }
  ];
  dotfiles.direnv.shells = [{
    dir = "comfyui";
    shellFile = ../../../shells/comfyui-rocm-gfx1151.nix;
  }];
	dotfiles.network = {
		hostname = "evo";
		interface = "eno1";
		staticIP = "${config.dotfiles.private.hosts.evo}/24";
		gateway = config.dotfiles.private.lan.gateway;
		wakeOnLan = true;
	};
}
