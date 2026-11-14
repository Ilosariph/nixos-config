{ inputs, config, ... }: {
  flake.nixosConfigurations.vps = inputs.nixpkgs.lib.nixosSystem {
    pkgs = import inputs.nixpkgs {
      system = "x86_64-linux";
      config.allowUnfree = true;
    };
    modules = [
      { nixpkgs.hostPlatform = "x86_64-linux"; }
      inputs.sops-nix.nixosModules.sops
      inputs.home-manager.nixosModules.home-manager
      inputs.nix-index-database.nixosModules.nix-index
      inputs.disko.nixosModules.disko
      inputs.nix-private.nixosModules.vps
      (inputs.import-tree ../machines/vps)
    ] ++ (builtins.attrValues config.flake.nixosModules) ++ [
      {
        home-manager.users.simon.imports = [
          ../machines/vps/_home.nix
        ];
      }
    ];
  };
}
