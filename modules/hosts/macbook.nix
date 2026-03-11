{ inputs, config, ... }: {
  flake.nixosConfigurations.macbook = inputs.nixpkgs.lib.nixosSystem {
    system = "aarch64-linux";
    pkgs = import inputs.nixpkgs {
      system = "aarch64-linux";
      config.allowUnfree = true;
    };
    modules = [
      inputs.apple-silicon.nixosModules.apple-silicon-support
      inputs.sops-nix.nixosModules.sops
      inputs.home-manager.nixosModules.home-manager
      (inputs.import-tree ../machines/macbook)
    ] ++ (builtins.attrValues config.flake.nixosModules);
  };
}
