{ ... }: {
  # Servers watch each other with signed UDP heartbeats (heartbeat.py) and post
  # to Discord when one goes down / comes back. Hosts with a MAC in
  # dotfiles.private.macs and `wol = true` are woken when down (and not pingable).
  # A hub (`reply`) answers heartbeats, so hosts behind NAT see it although it
  # can't reach them. Of all live hosts watching a down host, the one with the
  # lowest `priority` posts, so there's one message per event.
  #
  #   heartbeat status          peers as seen from here
  #   heartbeat maint 2h        no alerts / WoL for this host for 2h
  #   heartbeat done            end it early
  #
  # reboot/poweroff announce themselves on shutdown: peers stay quiet for
  # rebootWindow (reboot) or until the host is back (poweroff, no WoL either).
  #
  # Secrets (sops, shared.yaml): heartbeat-key (random HMAC key, e.g.
  # `openssl rand -hex 32`), heartbeat-discord-webhook (webhook URL).
  flake.nixosModules.heartbeat = { config, lib, pkgs, ... }:
    let
      cfg = config.dotfiles.services.heartbeat;
      macs = config.dotfiles.private.macs or { };

      heartbeat = pkgs.writers.writePython3Bin "heartbeat" {
        flakeIgnore = [ "E501" ];
      } (builtins.readFile ./heartbeat.py);

      configFile = pkgs.writeText "heartbeat.json" (builtins.toJSON {
        self = config.networking.hostName;
        inherit (cfg) port interval timeout rebootWindow priority reply wolAttempts wolInterval;
        peers = lib.mapAttrs (name: p: {
          inherit (p) address watch;
          send = p.send && p.address != null;
          mac = if p.wol then macs.${name} or (throw "heartbeat: no dotfiles.private.macs.${name} for WoL") else null;
        }) cfg.peers;
      });

      secret = name: config.sops.secrets.${name}.path;
    in
    lib.mkIf cfg.enable {
      environment.systemPackages = [ heartbeat ];
      networking.firewall.allowedUDPPorts = [ cfg.port ];

      sops.secrets.${cfg.keySecret}.sopsFile = config.dotfiles.sops.sharedSecretsFile;
      sops.secrets.${cfg.webhookSecret}.sopsFile = config.dotfiles.sops.sharedSecretsFile;

      systemd.services.heartbeat = {
        description = "Server heartbeats";
        wantedBy = [ "multi-user.target" ];
        wants = [ "network-online.target" ];
        after = [ "network-online.target" ];
        path = [ pkgs.iputils ];
        serviceConfig = {
          ExecStart = "${heartbeat}/bin/heartbeat daemon ${configFile}";
          Restart = "always";
          RestartSec = 5;
          DynamicUser = true;
          RuntimeDirectory = "heartbeat";
          RuntimeDirectoryMode = "0755";
          # Keeps a `maint` announcement across daemon restarts (e.g. switch).
          RuntimeDirectoryPreserve = true;
          LoadCredential = [ "key:${secret cfg.keySecret}" "webhook:${secret cfg.webhookSecret}" ];
          AmbientCapabilities = [ "CAP_NET_RAW" ];
          CapabilityBoundingSet = [ "CAP_NET_RAW" ];
          NoNewPrivileges = true;
          ProtectSystem = "strict";
          ProtectHome = true;
          PrivateTmp = true;
          PrivateDevices = true;
          ProtectKernelTunables = true;
          ProtectKernelModules = true;
          ProtectControlGroups = true;
          RestrictAddressFamilies = [ "AF_INET" "AF_INET6" "AF_UNIX" ];
          RestrictNamespaces = true;
          LockPersonality = true;
          MemoryDenyWriteExecute = true;
          SystemCallArchitectures = "native";
        };
      };

      # Stopped (ExecStop) only on shutdown: announces reboot/poweroff and waits
      # until the daemon passed it on. Not restarted on switch, so a switch never
      # announces anything.
      systemd.services.heartbeat-shutdown = {
        description = "Announce reboot/poweroff to heartbeat peers";
        wantedBy = [ "multi-user.target" ];
        after = [ "heartbeat.service" "network-online.target" ];
        wants = [ "network-online.target" ];
        restartIfChanged = false;
        path = [ config.systemd.package ];
        serviceConfig = {
          Type = "oneshot";
          RemainAfterExit = true;
          ExecStart = "${pkgs.coreutils}/bin/true";
          ExecStop = "${heartbeat}/bin/heartbeat shutdown-hook ${toString cfg.rebootWindow} ${toString (cfg.interval + 15)}";
          TimeoutStopSec = cfg.interval + 30;
        };
      };
    };
}
