{ inputs, ... }: {
  # Private-but-not-secret values (LAN layout, domains, public keys, IDs) from
  # private.nix in the nix-secrets input. Read at eval time and end up in the
  # world-readable store, so nothing that needs encryption: that stays in sops.
  # See docs/secrets.md.
  flake.nixosModules.private = {
    dotfiles.private = import "${inputs.nix-secrets}/private.nix";
  };
}
