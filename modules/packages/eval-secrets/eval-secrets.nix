{ ... }: {
  flake.nixosModules.eval-secrets = { ... }: {
    _module.args.evalSecrets = import ../../../nix/eval-secrets.nix;
  };
}
