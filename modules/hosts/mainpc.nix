{ inputs, config, ... }: {
  flake.nixosConfigurations.mainpc = inputs.nixpkgs.lib.nixosSystem {
    pkgs = import inputs.nixpkgs {
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
    modules = [
      { nixpkgs.hostPlatform = "x86_64-linux"; }
      inputs.sops-nix.nixosModules.sops
      inputs.nixpkgs-xr.nixosModules.nixpkgs-xr
      inputs.home-manager.nixosModules.home-manager
      inputs.nix-index-database.nixosModules.nix-index
      inputs.yeetmouse.nixosModules.default
      (inputs.import-tree ../machines/mainpc)
    ] ++ (builtins.attrValues config.flake.nixosModules) ++ [
      ({ pkgs, ... }: {
        services.udev.packages = [ pkgs.streamcontroller ];
        home-manager.users.simon = { pkgs, config, ... }: {
          home.packages = with pkgs; [ streamcontroller ];
          home.file.data = {
            source = config.lib.file.mkOutOfStoreSymlink "/data";
            target = "data";
          };
        };
      })
    ];
  };
}
