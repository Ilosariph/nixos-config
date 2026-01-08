{
  networking = {
		networkmanager.enable = true;
		networkmanager.dns = "none";

		nameservers = [
			"192.168.1.148"
			"fd32:9975:719f:0:7a55:36ff:fe02:15f3"
			"1.1.1.1"
			"2606:4700:4700::1111"
			"1.0.0.1"
			"2606:4700:4700::1001"
		];
  };
	services.dnsmasq.resolveLocalQueries = false;
}
