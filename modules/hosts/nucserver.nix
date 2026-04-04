{ inputs, config, ... }: {
  flake.nixosConfigurations.nucserver = inputs.nixpkgs.lib.nixosSystem {
    system = "x86_64-linux";
    pkgs = import inputs.nixpkgs {
      system = "x86_64-linux";
      config.allowUnfree = true;
    };
    modules = [
      inputs.sops-nix.nixosModules.sops
      inputs.home-manager.nixosModules.home-manager
      inputs.nix-index-database.nixosModules.nix-index
      (inputs.import-tree ../machines/nucserver)
    ] ++ (builtins.attrValues config.flake.nixosModules) ++ [
      {
        home-manager.users.simon.imports = [
          ../machines/nucserver/_home.nix
        ];
      }
    ];
  };
}
