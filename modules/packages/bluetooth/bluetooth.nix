{ ... }: {
  flake.nixosModules.bluetooth = { config, lib, ... }: {
    config = lib.mkIf config.dotfiles.bluetooth.enable {
      hardware.bluetooth.enable = true;
    };
  };
}
