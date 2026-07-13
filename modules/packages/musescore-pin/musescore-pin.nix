{ inputs, ... }: {
  # Temporary: musescore is broken in current nixos-unstable
  # (makeCWrapper: Unknown argument --prefix LD_LIBRARY_PATH).
  # Overlay it from a pinned older nixpkgs. Remove this aspect once
  # the upstream musescore build is fixed.
  flake.nixosModules.musescore-pin = { pkgs, ... }: {
    nixpkgs.overlays = [
      (final: prev: {
        musescore = (import inputs.nixpkgs-musescore {
          inherit (final.stdenv.hostPlatform) system;
          config.allowUnfree = prev.config.allowUnfree or false;
        }).musescore;
      })
    ];
  };
}
