{ inputs, config, ... }: {
  flake.nixosConfigurations.laptopserver = inputs.nixpkgs.lib.nixosSystem {
    pkgs = import inputs.nixpkgs {
      system = "x86_64-linux";
      config.allowUnfree = true;
    };
    modules = [
      { nixpkgs.hostPlatform = "x86_64-linux"; }
      inputs.sops-nix.nixosModules.sops
      inputs.home-manager.nixosModules.home-manager
      inputs.nix-index-database.nixosModules.nix-index
      (inputs.import-tree ../machines/laptopserver)
    ] ++ (builtins.attrValues config.flake.nixosModules);
  };
}
