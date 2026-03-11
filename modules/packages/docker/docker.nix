{ ... }: {
  flake.nixosModules.docker = { config, ... }: {
    virtualisation.docker.enable = config.dotfiles.programs.docker.enable;
  };
}
