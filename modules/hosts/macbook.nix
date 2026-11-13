{ inputs, config, ... }: {
  flake.nixosConfigurations.macbook = inputs.nixpkgs.lib.nixosSystem {
    pkgs = import inputs.nixpkgs {
      system = "aarch64-linux";
      config.allowUnfree = true;
    };
    specialArgs = { inherit inputs; };
    modules = [
      { nixpkgs.hostPlatform = "aarch64-linux"; }
      inputs.apple-silicon.nixosModules.apple-silicon-support
      inputs.sops-nix.nixosModules.sops
      inputs.home-manager.nixosModules.home-manager
      inputs.nix-index-database.nixosModules.nix-index
      inputs.nix-private.nixosModules.default
      inputs.nix-private.nixosModules.macbook
      (inputs.import-tree ../machines/macbook)
    ] ++ (builtins.attrValues config.flake.nixosModules);
  };
}
