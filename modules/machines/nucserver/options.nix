{ ... }:
{
  dotfiles.sops.enable = true;
  dotfiles.sops.defaultSecretsFile = ../../../secrets.yaml;
  dotfiles.bootloader.type = "systemd";
  dotfiles.programs._1password.sshAgent = false;
  dotfiles.services.ssh.enable = true;
  dotfiles.services.ssh.authorizedKeySecret = "nucserver-ssh-public-key";
  dotfiles.services.fail2ban.enable = true;
  dotfiles.network.wakeOnLan = true;
}
