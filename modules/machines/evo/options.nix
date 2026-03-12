{ ... }:
{
  dotfiles.bootloader.type = "systemd";
  dotfiles.programs._1password.sshAgent = false;
  dotfiles.services.ssh.enable = true;
  dotfiles.services.ssh.authorizedKeySecret = "nucserver-ssh-public-key";
  dotfiles.services.fail2ban.enable = true;
  dotfiles.services.pangolinNewt = {
    enable = true;
    endpoint = "https://pangolin.simon-wick.ch";
    idSecret = "evo-newt-id";
    secretSecret = "evo-newt-secret";
  };
  dotfiles.shares = [
    {
      mountPoint = "/mnt/projects";
      share = "p";
      credentials = "/etc/nixos/smb-p";
    }
  ];
	dotfiles.network = {
		hostname = "evo";
		interface = "eno1";
		staticIP = "192.168.1.105/24";
		gateway = "192.168.1.1";
		wakeOnLan = true;
	};
}
