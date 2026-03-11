{ ... }: {
  flake.nixosModules.fail2ban = { config, ... }: {
    services.fail2ban.enable = config.dotfiles.services.fail2ban.enable;
  };
}
