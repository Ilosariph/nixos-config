{ config, ... }:
let
  home = config.users.users.${config.dotfiles.user.name}.home;
in
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
  dotfiles.services.seerr.enable = true;
  dotfiles.services.fail2ban.enable = true;
  dotfiles.services.hermes.enable = true;
  dotfiles.services.nixEval.enable = true;
  dotfiles.services.backup.enable = true;
  dotfiles.services.backup.jobs = [
    {
      name = "docker-configs";
      source = "${home}/docker/";
      destination = "/mnt/docker-backup/evo";
      calendar = "*-*-* 03:00:00";
      mode = "snapshot";
      keep = 3;
    }
    {
      # Container writes as uid 10000 with 0700 dirs (memories, sessions, skills) -> root.
      # projects/ is the CIFS hermes share (not on evo's disk); caches are rebuildable.
      name = "hermes";
      source = "${home}/.hermes/";
      destination = "/mnt/docker-backup/evo-hermes";
      calendar = "*-*-* 03:15:00";
      mode = "snapshot";
      keep = 7;
      user = "root";
      sqlite = true;
      excludes = [ "/projects/" "/cache/" "/.cache/" "/image_cache/" "/audio_cache/" "/lazy-packages/" "/home/.cache/" ];
    }
    {
      # DynamicUser StateDirectory (private/, 0700) -> root. data/cache holds downloaded
      # embedding models, static/ is regenerated on start.
      name = "open-webui";
      source = "/var/lib/private/open-webui/";
      destination = "/mnt/docker-backup/evo-open-webui";
      calendar = "*-*-* 03:30:00";
      mode = "snapshot";
      keep = 7;
      user = "root";
      sqlite = true;
      excludes = [ "/data/cache/" "/static/" ];
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
      # Server rejects native symlinks (rsync code 23); store them as MF symlink files.
      extraOptions = [ "mfsymlinks" ];
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
