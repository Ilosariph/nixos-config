{ config, ... }:
let
  vps = config.dotfiles.private.vps;
in
{
  dotfiles.sops.enable = true;
  dotfiles.sops.host = "vps";
  dotfiles.deploy.target.enable = true;
  dotfiles.deploy.target.trustedPublicKeys = [ config.dotfiles.private.nix.mainpcSigningPublicKey ];
  dotfiles.kernel = "stable";
  dotfiles.bootloader.type = "grub";
  dotfiles.bootloader.grubDevice = "/dev/sda";
  dotfiles.programs._1password.sshAgent = false;
  dotfiles.services.ssh.enable = true;
  dotfiles.services.ssh.authorizedKeys = vps.authorizedKeys;
  # CrowdSec (crowdsec.nix) covers sshd.
  dotfiles.services.fail2ban.enable = false;
  dotfiles.network = {
    hostname = "vps";
    interface = "eth0";
    staticIP = "${vps.ipv4}/${toString (vps.prefixLength or 24)}";
    gateway = vps.gateway;
    nameservers = [
      "1.1.1.1"
      "2606:4700:4700::1111"
      "1.0.0.1"
      "2606:4700:4700::1001"
    ];
  };
}
