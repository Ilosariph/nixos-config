{ ... }: {
  # Deployer side only: mainpc-finix pushes to the NixOS servers with deploy-rs.
  # Being a deploy target needs deploy-rs' NixOS activation, so finix hosts
  # cannot set dotfiles.deploy.target.enable.
  flake.finixModules.deploy = { config, lib, pkgs, ... }:
    let
      dep = config.dotfiles.deploy.deployer;
    in lib.mkMerge [
      {
        assertions = [
          {
            assertion = !config.dotfiles.deploy.target.enable;
            message = "finix hosts cannot be deploy-rs targets (dotfiles.deploy.target.enable).";
          }
        ];
      }

      (lib.mkIf dep.installTool {
        environment.systemPackages = [ pkgs.deploy-rs ];

        sops.secrets = lib.mkIf (dep.signingKeySecret != null) {
          ${dep.signingKeySecret} = {
            path = "/etc/nix/signing-key.sec";
            owner = "root";
            mode = "0400";
          };
        };

        services.nix-daemon.settings.secret-key-files =
          lib.mkIf (dep.signingKeySecret != null) [ "/etc/nix/signing-key.sec" ];
      })
    ];
}
