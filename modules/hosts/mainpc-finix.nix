{ inputs, config, ... }: {
  # mainpc on finix (finit as PID 1, no systemd), for testing alongside the
  # NixOS mainpc config. Built from the shared dotfiles.* options plus the
  # finix aspects under modules/finix/ (flake.finixModules.*).
  # Build: nh os switch . -H mainpc-finix   (or ./build.sh mainpc-finix nix)
  flake.nixosConfigurations.mainpc-finix = inputs.finix.lib.finixSystem {
    inherit (inputs.nixpkgs) lib;
    specialArgs = { inherit inputs; };
    modules = [
      {
        nixpkgs.pkgs = import inputs.nixpkgs {
          system = "x86_64-linux";
          config.allowUnfree = true;
          # Temporary: musescore is broken in current nixos-unstable
          # (makeCWrapper: Unknown argument --prefix LD_LIBRARY_PATH).
          # Pull it from a pinned older nixpkgs until upstream is fixed.
          overlays = [
            (final: prev: {
              musescore = (import inputs.nixpkgs-musescore {
                inherit (final.stdenv.hostPlatform) system;
                config.allowUnfree = true;
              }).musescore;
            })
          ];
        };
      }
      ../../options.nix
      ../machines/mainpc/options.nix
      ../machines/mainpc/drives.nix
      (inputs.import-tree ../machines/mainpc-finix)
    ] ++ (builtins.attrValues config.flake.finixModules);
  };
}
