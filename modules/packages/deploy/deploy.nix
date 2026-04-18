{ inputs, config, ... }:
let
  lib = inputs.nixpkgs.lib;

  allConfigs = config.flake.nixosConfigurations;

  deployableConfigs = lib.filterAttrs
    (_: nixosCfg: nixosCfg.config.dotfiles.deploy.target.enable)
    allConfigs;

  resolveHostname = name: nixosCfg:
    let d = nixosCfg.config.dotfiles; in
      if d.deploy.target.hostname != null then d.deploy.target.hostname
      else if d.network.staticIP != null then lib.head (lib.splitString "/" d.network.staticIP)
      else if d.network.hostname != null then d.network.hostname
      else throw "deploy: ${name} has deploy.target.enable but no resolvable hostname";

  mkNode = name: nixosCfg:
    let
      d = nixosCfg.config.dotfiles;
      system = nixosCfg.pkgs.stdenv.hostPlatform.system;
      activationUser = d.deploy.target.user;
      sshUser = if d.deploy.target.sshUser != null then d.deploy.target.sshUser else activationUser;
    in {
      hostname = resolveHostname name nixosCfg;
      remoteBuild = d.deploy.target.remoteBuild;
      inherit sshUser;
      profiles.system = {
        user = "root";
        path = inputs.deploy-rs.lib.${system}.activate.nixos nixosCfg;
      };
    };

  deployNodes = lib.mapAttrs mkNode deployableConfigs;
in {
  flake.nixosModules.deploy = { config, lib, pkgs, ... }:
    let
      t = config.dotfiles.deploy.target;
      dep = config.dotfiles.deploy.deployer;
    in
    lib.mkMerge [
      (lib.mkIf dep.installTool {
        environment.systemPackages = [ pkgs.deploy-rs ];

        sops = lib.mkIf (dep.signingKeySecret != null) {
          secrets.${dep.signingKeySecret} = {
            path = "/etc/nix/signing-key.sec";
            owner = "root";
            mode = "0400";
          };
        };

        nix.settings.secret-key-files = lib.mkIf (dep.signingKeySecret != null)
          [ "/etc/nix/signing-key.sec" ];

      })

      (lib.mkIf t.enable {
        security.sudo.extraRules = [{
          users = [ config.dotfiles.user.name ];
          commands = [
            { command = "/nix/store/*/bin/switch-to-configuration *"; options = [ "NOPASSWD" ]; }
            { command = "/nix/store/*/activate-rs *"; options = [ "NOPASSWD" ]; }
            { command = "/nix/store/*/*/activate-rs *"; options = [ "NOPASSWD" ]; }
            { command = "/nix/store/*/deploy-rs-activate *"; options = [ "NOPASSWD" ]; }
            { command = "/nix/store/*/*/deploy-rs-activate *"; options = [ "NOPASSWD" ]; }
            { command = "/run/current-system/sw/bin/rm /tmp/deploy-rs*"; options = [ "NOPASSWD" ]; }
            { command = "/bin/rm /tmp/deploy-rs*"; options = [ "NOPASSWD" ]; }
          ];
        }];
      })

      (lib.mkIf (t.trustedPublicKeySecret != null) {
        sops.secrets.${t.trustedPublicKeySecret} = {
          path = "/etc/nix/trusted-public-key";
          owner = "root";
          mode = "0444";
        };

        nix.extraOptions = ''
          !include /etc/nix/trusted-public-key
        '';

        nix.settings.trusted-public-keys = [
          "cache.nixos.org-1:6NCHdD59X431o0gWypbMrAURkbJ16ZPMQFGspcDShjY="
        ];
      })
    ];

  flake.deploy.nodes = deployNodes;

  flake.checks = lib.mapAttrs
    (_system: deployLib: deployLib.deployChecks { nodes = deployNodes; })
    inputs.deploy-rs.lib;
}
