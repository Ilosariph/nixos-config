# CrowdSec on the host: sshd (replaces fail2ban) and Immich's failed logins,
# enforced by the firewall bouncer on INPUT and DOCKER-USER.
# Internet traffic to Immich comes through newt, so here it's local traffic and
# a ban doesn't stop it: that's blocked on the VPS (vps/crowdsec.nix,
# vps/immich-bf on traefik's log). This one covers direct hits (LAN is
# whitelisted, crowdsecurity/whitelists) and feeds the community blocklist.
{ config, ... }:
let
  dataDir = config.services.crowdsec.settings.config.config_paths.data_dir;
  # 8080 is a common docker port; LAPI only needs loopback.
  lapi = "127.0.0.1:8180";
in
{
  # Docker's journald driver tags entries with SYSLOG_IDENTIFIER=<tag>; with the
  # container name as tag, syslog-logs sets evt.Parsed.program to it. Takes
  # effect on recreated containers (`docker compose up -d --force-recreate`).
  virtualisation.docker.daemon.settings.log-opts.tag = "{{.Name}}";

  services.crowdsec = {
    enable = true;
    autoUpdateService = true;

    hub = {
      collections = [
        "crowdsecurity/linux" # syslog + sshd + geoip
        "crowdsecurity/whitelist-good-actors"
      ];
      # Hub's gauth-fr/immich-logs expects program 'immich'; parser below
      # instead, its log_type feeds these.
      scenarios = [ "gauth-fr/immich-bf" ];
      # Never ban private ranges (LAN, docker bridges, newt).
      parsers = [ "crowdsecurity/whitelists" ];
    };

    # Journal access for the journalctl datasource.
    extraGroups = [ "systemd-journal" ];

    settings = {
      config = {
        db_config.use_wal = true;
        # Same reason as on the VPS: the version branch misses newer hub items.
        cscli.hub_branch = "master";
        api.server = {
          listen_uri = lapi;
          online_client = {
            credentials_path = "${dataDir}/online_api_credentials.yaml";
            sharing = true;
            pull = {
              community = true;
              blocklists = true;
            };
          };
        };
      };

      acquisitions = [
        {
          source = "journalctl";
          journalctl_filter = [ "_SYSTEMD_UNIT=sshd.service" ];
          labels.type = "syslog";
        }
        {
          source = "journalctl";
          journalctl_filter = [ "CONTAINER_NAME=immich_server" ];
          labels.type = "syslog";
        }
      ];

      # `[Nest] 7 - 11/12/2026, 10:00:00 PM WARN [Api:AuthService] Failed login
      # attempt for user x@y.z from ip address 1.2.3.4` (maybe with ANSI colours).
      # IP is the real client: Immich trusts X-Forwarded-For from private ranges
      # (newt via docker bridge). Timestamp from journald.
      parsers.s01Parse = [{
        name = "nucserver/immich-logs";
        description = "Immich failed logins";
        filter = "evt.Parsed.program == 'immich_server'";
        onsuccess = "next_stage";
        grok = {
          pattern = "Failed login attempt for user %{DATA:username} from ip address %{IP:source_ip}";
          apply_on = "message";
        };
        statics = [
          { meta = "log_type"; value = "immich_failed_auth"; }
          { meta = "service"; value = "immich"; }
          { meta = "user"; expression = "evt.Parsed.username"; }
          { meta = "source_ip"; expression = "evt.Parsed.source_ip"; }
        ];
      }];

      profiles = [
        {
          name = "default_ip_remediation";
          filters = [ "Alert.Remediation == true && Alert.GetScope() == 'Ip'" ];
          decisions = [{ type = "ban"; duration = "4h"; }];
          # Repeat offenders: 4h, 8h, 12h, ... (%% = literal %, tmpfiles specifier).
          duration_expr = "Sprintf('%%dh', (GetDecisionsCount(Alert.GetValue()) + 1) * 4)";
          on_success = "break";
        }
        {
          name = "default_range_remediation";
          filters = [ "Alert.Remediation == true && Alert.GetScope() == 'Range'" ];
          decisions = [{ type = "ban"; duration = "4h"; }];
          on_success = "break";
        }
      ];
    };
  };

  # cscli fails on a missing CAPI credentials file: start with an empty one
  # (setup registers if empty).
  systemd.tmpfiles.rules = [
    "f ${dataDir}/online_api_credentials.yaml 0600 ${config.services.crowdsec.user} ${config.services.crowdsec.group} -"
  ];
  # settings land in /etc/crowdsec via tmpfiles, outside the unit.
  systemd.services.crowdsec.restartTriggers = [ (builtins.toJSON config.services.crowdsec.settings) ];

  services.crowdsec-firewall-bouncer = {
    enable = true;
    settings = {
      mode = "iptables";
      api_url = "http://${lapi}";
      # DOCKER-USER sees DNATed traffic to published container ports, which
      # never passes INPUT.
      iptables_chains = [ "INPUT" "DOCKER-USER" ];
    };
  };
  # DOCKER-USER only exists once dockerd has set up its chains.
  systemd.services.crowdsec-firewall-bouncer = {
    after = [ "docker.service" "crowdsec-firewall-bouncer-register.service" ];
    wants = [ "docker.service" ];
  };
}
