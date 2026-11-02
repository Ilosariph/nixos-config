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

      users.users.pangolin-newt = {
        isSystemUser = true;
        group = "pangolin-newt";
      };
      users.groups.pangolin-newt = { };

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
          # Static user (not DynamicUser) so per-host firewall rules can match
          # newt's traffic by UID (e.g. evo's comfyui loopback allowlist).
          User = "pangolin-newt";
          Group = "pangolin-newt";
          StateDirectory = "pangolin-newt";
          # newt keeps its config (WireGuard keys) under $HOME/.config/newt-client;
          # the system user's home is /var/empty, so point it at the state dir.
          Environment = "HOME=/var/lib/pangolin-newt";
          WorkingDirectory = "/var/lib/pangolin-newt";
        };
      };
    };
}
