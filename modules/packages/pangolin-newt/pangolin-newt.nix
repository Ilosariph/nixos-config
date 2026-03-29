{ ... }: {
  flake.nixosModules.pangolin-newt = { config, lib, pkgs, ... }:
    let
      cfg = config.dotfiles.services.pangolinNewt;
    in
    lib.mkIf cfg.enable {
      sops = {
        secrets.${cfg.idSecret} = { };
        secrets.${cfg.secretSecret} = { };
        templates."newt-env".content = ''
          NEWT_ID=${config.sops.placeholder.${cfg.idSecret}}
          NEWT_SECRET=${config.sops.placeholder.${cfg.secretSecret}}
        '';
      };

      systemd.services.pangolin-newt = {
        description = "Pangolin Newt tunnel client";
        after = [ "network-online.target" ];
        wants = [ "network-online.target" ];
        wantedBy = [ "multi-user.target" ];
        serviceConfig = {
          ExecStart = "${pkgs.fosrl-newt}/bin/newt --endpoint ${cfg.endpoint}";
          EnvironmentFile = config.sops.templates."newt-env".path;
          Restart = "on-failure";
          RestartSec = "5s";
          DynamicUser = true;
        };
      };
    };
}
