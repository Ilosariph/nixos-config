{ inputs, config, ... }: {
  flake.nixosConfigurations.macbook = inputs.nixpkgs.lib.nixosSystem {
    pkgs = import inputs.nixpkgs {
      system = "aarch64-linux";
      config.allowUnfree = true;
    };
    modules = [
      { nixpkgs.hostPlatform = "aarch64-linux"; }
      inputs.apple-silicon.nixosModules.apple-silicon-support
      inputs.sops-nix.nixosModules.sops
      inputs.home-manager.nixosModules.home-manager
      inputs.nix-index-database.nixosModules.nix-index
      (inputs.import-tree ../machines/macbook)
    ] ++ (builtins.attrValues config.flake.nixosModules);
  };
}
