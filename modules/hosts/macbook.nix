{ inputs, config, ... }: {
  flake.nixosConfigurations.macbook = inputs.nixpkgs.lib.nixosSystem {
    pkgs = import inputs.nixpkgs {
      system = "aarch64-linux";
      config.allowUnfree = true;
    };
    # kernel.nix pins the Asahi kernel source to a flake input
    specialArgs = { inherit inputs; };
    modules = [
      { nixpkgs.hostPlatform = "aarch64-linux"; }
      inputs.apple-silicon.nixosModules.apple-silicon-support
      inputs.sops-nix.nixosModules.sops
      inputs.home-manager.nixosModules.home-manager
      inputs.nix-index-database.nixosModules.nix-index
      inputs.yeetmouse.nixosModules.default
      (inputs.import-tree ../machines/macbook)
    ] ++ (builtins.attrValues config.flake.nixosModules);
  };
}
