{ inputs, config, ... }: {
  flake.nixosConfigurations.mainpc = inputs.nixpkgs.lib.nixosSystem {
    pkgs = import inputs.nixpkgs {
      system = "x86_64-linux";
      config.allowUnfree = true;
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
