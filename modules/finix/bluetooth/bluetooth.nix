{ ... }: {
  flake.finixModules.bluetooth = { config, modules, ... }: {
    imports = [ modules.bluetooth ];
    services.bluetooth.enable = config.dotfiles.bluetooth.enable;
  };
}
