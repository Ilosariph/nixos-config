{
	sops = {
		age.keyFile = "/home/simon/.config/sops/age/keys.txt";
		defaultSopsFile = ../../../../secrets.yaml;

		secrets.nucserver-ssh-public-key = {
			path = "/home/simon/.ssh/authorized_keys";
			owner = "simon";
			group = "users";
			mode = "0400";
		};
	};
}
