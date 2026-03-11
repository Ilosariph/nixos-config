{ inputs, config, lib, ... }:
let
  mkMainpc = wmOverride: inputs.nixpkgs.lib.nixosSystem {
    system = "x86_64-linux";
    pkgs = import inputs.nixpkgs {
      system = "x86_64-linux";
      config.allowUnfree = true;
    };
    modules = [
      inputs.sops-nix.nixosModules.sops
      inputs.nixpkgs-xr.nixosModules.nixpkgs-xr
      inputs.home-manager.nixosModules.home-manager
      (inputs.import-tree ../machines/mainpc)
    ] ++ lib.optional (wmOverride != null) { dotfiles.windowManager.type = lib.mkForce wmOverride; }
      ++ (builtins.attrValues config.flake.nixosModules) ++ [
      {
        home-manager.users.simon = { pkgs, config, ... }: {
          home.packages = with pkgs; [ streamcontroller ];
          home.file.data = {
            source = config.lib.file.mkOutOfStoreSymlink "/data";
            target = "data";
          };
        };
      }
    ];
  };
in {
  flake.nixosConfigurations.mainpc      = mkMainpc null;
  flake.nixosConfigurations.mainpc-niri = mkMainpc "niri";
}
