{ inputs, config, ... }: {
  flake.nixosConfigurations.laptopserver = inputs.nixpkgs.lib.nixosSystem {
    system = "x86_64-linux";
    pkgs = import inputs.nixpkgs {
      system = "x86_64-linux";
      config.allowUnfree = true;
    };
    modules = [
      inputs.sops-nix.nixosModules.sops
      inputs.home-manager.nixosModules.home-manager
      (inputs.import-tree ../machines/laptopserver)
    ] ++ (builtins.attrValues config.flake.nixosModules);
  };
}
