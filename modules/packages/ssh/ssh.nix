{ ... }: {
  flake.nixosModules.ssh = { config, lib, ... }: {
    services.openssh.enable = config.dotfiles.services.ssh.enable;

    users.users.${config.dotfiles.user.name}.openssh.authorizedKeys.keys =
      config.dotfiles.services.ssh.authorizedKeys;
  };
}
