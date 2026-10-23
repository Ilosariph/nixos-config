{ config, ... }:
{
  dotfiles.sops.enable = true;
  dotfiles.sops.host = "nucserver";
  dotfiles.kernel = "stable";
  dotfiles.bootloader.type = "systemd";
  dotfiles.programs._1password.sshAgent = false;
  dotfiles.services.ssh.enable = true;
  dotfiles.services.ssh.authorizedKeys = config.dotfiles.private.ssh.authorizedKeys;
  dotfiles.services.fail2ban.enable = true;
  dotfiles.network.wakeOnLan = true;
}
