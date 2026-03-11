{ ... }: {
  flake.nixosModules.ssh = { config, lib, ... }: {
    services.openssh.enable = config.dotfiles.services.ssh.enable;

    sops = lib.mkIf (config.dotfiles.services.ssh.authorizedKeySecret != null) {
      age.keyFile = "/home/${config.dotfiles.user.name}/.config/sops/age/keys.txt";
      defaultSopsFile = lib.mkDefault ../../../secrets.yaml;
      secrets.${config.dotfiles.services.ssh.authorizedKeySecret} = {
        path = "/home/${config.dotfiles.user.name}/.ssh/authorized_keys";
        owner = config.dotfiles.user.name;
        group = "users";
        mode = "0400";
      };
    };
  };
}
