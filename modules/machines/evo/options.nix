{ evalSecrets, ... }:
{
  dotfiles.sops.enable = true;
  dotfiles.sops.defaultSecretsFile = ../../../secrets/secrets.yaml;
  dotfiles.deploy.target.enable = true;
  dotfiles.deploy.target.trustedPublicKeySecret = "mainpc-nix-signing-key-pub";
  dotfiles.kernel = "default";
  dotfiles.bootloader.type = "systemd";
  dotfiles.programs._1password.sshAgent = false;
  dotfiles.services.ssh.enable = true;
  dotfiles.services.ssh.authorizedKeySecret = "nucserver-ssh-public-key";
  dotfiles.services.jellyfin = {
    enable = true;
    publishedServerUrl = evalSecrets.evo.jellyfinUrl;
  };
  dotfiles.services.fail2ban.enable = true;
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
    endpoint = evalSecrets.evo.pangolinEndpoint;
    idSecret = "evo-newt-id";
    secretSecret = "evo-newt-secret";
  };
  dotfiles.sharesDefaultServer = evalSecrets.nasServerIP;
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
    staticIP = evalSecrets.evo.staticIP;
    gateway = evalSecrets.defaultGateway;
    wakeOnLan = true;
    nameservers = [
      evalSecrets.privateDnsIPv4
      evalSecrets.privateDnsIPv6
      "1.1.1.1"
      "2606:4700:4700::1111"
      "1.0.0.1"
      "2606:4700:4700::1001"
    ];
  };
}
