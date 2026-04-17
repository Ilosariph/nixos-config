{ inputs, config, ... }: {
  flake.nixosConfigurations.evo = inputs.nixpkgs.lib.nixosSystem {
    pkgs = import inputs.nixpkgs {
      system = "x86_64-linux";
      config.allowUnfree = true;
    };
    modules = [
      { nixpkgs.hostPlatform = "x86_64-linux"; }
      inputs.sops-nix.nixosModules.sops
      inputs.home-manager.nixosModules.home-manager
      inputs.nix-index-database.nixosModules.nix-index
      (inputs.import-tree ../machines/evo)
    ] ++ (builtins.attrValues config.flake.nixosModules) ++ [
      { _module.args.openclawPkg = inputs.nix-openclaw.packages.x86_64-linux.default; }
      {
        home-manager.users.simon.imports = [
          ../machines/evo/_home.nix
          inputs.nix-openclaw.homeManagerModules.default
        ];
      }
    ];
  };
}
