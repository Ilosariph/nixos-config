{
	virtualisation.vmVariant = {
    users.users.nixosvmtest = {
      isNormalUser = true;
      password = "test";
      extraGroups = [ "wheel" ];
    };
  };
}
