{ inputs, ... }: {
  flake.nixosModules.sops = { config, lib, ... }:
    lib.mkIf config.dotfiles.sops.enable {
      dotfiles.sops.defaultSecretsFile = lib.mkDefault "${inputs.nix-secrets}/secrets.yaml";
      sops.age.keyFile = config.dotfiles.sops.ageKeyFile;
      sops.defaultSopsFile = config.dotfiles.sops.defaultSecretsFile;
    };
}
