{ ... }: {
  flake.nixosModules.sops = { config, lib, ... }:
    lib.mkIf config.dotfiles.sops.enable {
      sops.age.keyFile = config.dotfiles.sops.ageKeyFile;
      sops.defaultSopsFile = config.dotfiles.sops.defaultSecretsFile;
    };
}
