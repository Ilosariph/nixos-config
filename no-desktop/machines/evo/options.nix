{ ... }:
{
  dotfiles.bootloader = "systemd";
  dotfiles.use1PasswordAgent = false;
	dotfiles.network = {
		hostname = "evo";
		interface = "eno1";
		staticIP = "192.168.1.105/24";
		gateway = "192.168.1.1";
	};
}
