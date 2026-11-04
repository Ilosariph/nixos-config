# Throwaway second VPS to rehearse the vps install + restore against
# real data (docs/vps.md, "Test run"). Same config as vps with its own
# address; only defined while private.nix has a vps.test entry.
{ inputs, config, ... }:
let
  lib = inputs.nixpkgs.lib;
  private = import "${inputs.nix-secrets}/private.nix";
  test = private.vps.test or null;
in
{
  flake.nixosConfigurations = lib.optionalAttrs (test != null) {
    vps-test = inputs.nixpkgs.lib.nixosSystem {
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
        (inputs.import-tree ../machines/vps)
      ] ++ (builtins.attrValues config.flake.nixosModules) ++ [
        {
          home-manager.users.simon.imports = [
            ../machines/vps/_home.nix
          ];
        }
        {
          dotfiles.private.vps = {
            ipv4 = lib.mkForce test.ipv4;
            ipv6 = lib.mkForce test.ipv6;
            gateway = lib.mkForce test.gateway;
            prefixLength = lib.mkForce (test.prefixLength or 24);
          };
          dotfiles.network.hostname = lib.mkForce "vps-test";
          dotfiles.vps.migration.enable = true;
          # Same restic repo as prod: never back up from here (timer and
          # service masked). Restores (vps-migrate-restore, restic-vps) still work.
          systemd.timers.restic-backup.enable = false;
          systemd.services.restic-backup.enable = false;
        }
      ];
    };
  };
}
