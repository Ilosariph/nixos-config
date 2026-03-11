{ ... }: {
  flake.nixosModules._1password = { config, ... }: {
    programs._1password.enable = config.dotfiles.programs._1password.enable;
  };
}
