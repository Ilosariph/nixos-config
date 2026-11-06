# CrowdSec on the host, three enforcement points:
# - firewall bouncer: iptables bans on INPUT (sshd) and DOCKER-USER (everything
#   published by gerbil: traefik 80/443, WireGuard 51820/21820)
# - Traefik bouncer plugin (middleware config in pangolin.nix): ban +
#   Turnstile captcha per request, talks to this LAPI over docker0
# - AppSec (WAF) on :7422, queried inline by the same plugin
# Logs come from journald (docker's NixOS default log driver).
{ config, lib, pkgs, ... }:
let
  stateDir = "/var/lib/crowdsec/state";
  # Glob for a nix store hash (fixed length, hub items can't collide with it).
  storeHash = lib.concatStrings (lib.replicate 32 "?");
  # Fixed so the traefik plugin config in /docker can hardcode the LAPI address.
  dockerHost = "172.17.0.1";
  lapiPort = 8080;
  appsecPort = 7422;
  # Mounted read-only into the traefik container (see crowdsec-traefik-files).
  traefikDir = "/run/crowdsec-traefik";

  # Docker's journald driver tags entries with SYSLOG_IDENTIFIER=<tag>; the
  # daemon-wide tag below makes that the container name, so syslog-logs sets
  # evt.Parsed.program to it (traefik-logs and the pangolin parser filter on that).
  container = name: {
    source = "journalctl";
    journalctl_filter = [ "CONTAINER_NAME=${name}" ];
    labels.type = "syslog";
  };

  pluginFile = name: hash: pkgs.fetchurl {
    url = "https://raw.githubusercontent.com/maxlerebourg/crowdsec-bouncer-traefik-plugin/v1.8.1/${name}";
    inherit hash;
  };
  captchaHtml = pluginFile "captcha.html" "sha256-MziCo0fIeKY6Y8jk7TS5NBySzdXPt0bkobcEi046MrA=";
  banHtml = pluginFile "ban.html" "sha256-ZKGg2JiRTBzcaseX3mbqTZcOvfw6m5fv4Uki30xgVXo=";

  # Scenarios a human can trip by accident: captcha instead of ban.
  captchaScenarios = [
    "crowdsecurity/http-crawl-non_statics"
    "crowdsecurity/http-probing"
    "vps/pangolin-bf"
  ];

  secrets = config.sops.secrets;

  pangolinBf = name: capacity: label: {
    type = "leaky";
    inherit name capacity;
    description = "Brute force on Pangolin login or resource auth";
    filter = "evt.Meta.log_type == 'pangolin_failed_auth'";
    groupby = "evt.Meta.source_ip";
    leakspeed = "1m";
    blackhole = "5m";
    labels = {
      remediation = true;
      service = "pangolin";
      behavior = "http:bruteforce";
      inherit label;
      confidence = 3;
      spoofable = 0;
      classification = [ "attack.T1110" ];
    };
  };
in
{
  virtualisation.docker.daemon.settings = {
    log-opts.tag = "{{.Name}}";
    bip = "${dockerHost}/16";
  };

  sops.secrets.crowdsec-traefik-bouncer-key = { };
  sops.secrets.turnstile-site-key = { };
  sops.secrets.turnstile-secret-key = { };

  services.crowdsec = {
    enable = true;
    autoUpdateService = true;

    hub = {
      collections = [
        "crowdsecurity/linux" # syslog + sshd + geoip
        "crowdsecurity/traefik" # pangolin's traefik: every site behind it
        "crowdsecurity/http-cve"
        "crowdsecurity/whitelist-good-actors"
        "crowdsecurity/appsec-virtual-patching"
        "crowdsecurity/appsec-generic-rules"
      ];
      appsec-configs = [ "crowdsecurity/appsec-default" ];
      # Never ban private ranges (docker bridges, WireGuard peers).
      parsers = [ "crowdsecurity/whitelists" ];
    };

    # Journal access for the journalctl datasource. No upstream default.
    extraGroups = [ "systemd-journal" ];

    settings = {
      config = {
        # Upstream's default is /var/lib/crowdsec/data; keep the existing state
        # (DB with decisions, credentials, hub).
        config_paths.data_dir = stateDir;
        db_config.use_wal = true;
        # Unset, cscli uses the hub branch of its own version once a newer
        # crowdsec exists: that index lacks newer vpatch rules, which then get
        # ignored even though they're installed.
        cscli.hub_branch = "master";
        api = {
          client.credentials_path = "${stateDir}/local_api_credentials.yaml";
          server = {
            # Traefik reaches it via docker0; the firewall only lets docker bridges in.
            listen_uri = "0.0.0.0:${toString lapiPort}";
            # Registers with the central API on first start: shares signals,
            # pulls the community blocklist.
            online_client = {
              credentials_path = "${stateDir}/online_api_credentials.yaml";
              sharing = true;
              pull = {
                community = true;
                blocklists = true;
              };
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
        (container "traefik")
        # Needs app.log_failed_attempts: true in Pangolin's config.yml.
        (container "pangolin")
        {
          source = "appsec";
          name = "traefik-appsec";
          listen_addr = "0.0.0.0:${toString appsecPort}";
          appsec_config = "crowdsecurity/appsec-default";
          labels.type = "appsec";
        }
      ];

      # Pangolin's own login + resource auth (password, pin, email OTP, access
      # token). No hub parser exists; lines look like
      # `<ts> [info]: Username or password incorrect. Email: x. IP: 1.2.3.4.`
      parsers.s01Parse = [{
        name = "vps/pangolin-logs";
        description = "Pangolin failed authentication attempts";
        filter = "evt.Parsed.program == 'pangolin'";
        onsuccess = "next_stage";
        grok = {
          pattern = "(?:Username or password incorrect|Two-factor code incorrect|Resource password incorrect|Resource pin code incorrect|Resource email otp incorrect|Resource access token invalid|Email is not whitelisted)\\..* IP: %{IP:source_ip}\\.";
          apply_on = "message";
        };
        statics = [
          { meta = "log_type"; value = "pangolin_failed_auth"; }
          { meta = "service"; value = "pangolin"; }
          { meta = "source_ip"; expression = "evt.Parsed.source_ip"; }
        ];
      }];

      # Two stages on the same failed attempts (leak 1/min): captcha after 5,
      # ban after 10 (someone who solved the captcha and kept going).
      scenarios = [
        (pangolinBf "vps/pangolin-bf" 5 "Pangolin brute force")
        (pangolinBf "vps/pangolin-bf-ban" 10 "Pangolin brute force (past captcha)")
      ];

      # Includes the VPS itself: its image pulls from the own registry go out
      # and back in through traefik and look like a crawler.
      parsers.s02Enrich = [{
        name = "vps/trusted-ips";
        description = "Never ban own IPs";
        whitelist = {
          reason = "own IPs";
          cidr = (config.dotfiles.private.vps.trustedIPs or [ ])
            ++ [ "${config.dotfiles.private.vps.ipv4}/32" "${config.dotfiles.private.vps.ipv6}/128" ];
        };
      }];

      profiles = [
        {
          # Handled by the traefik plugin only; the firewall bouncer ignores captcha decisions.
          name = "captcha_remediation";
          filters = [
            "Alert.Remediation == true && Alert.GetScope() == 'Ip' && Alert.GetScenario() in ${builtins.toJSON captchaScenarios}"
          ];
          decisions = [{ type = "captcha"; duration = "4h"; }];
          on_success = "break";
        }
        {
          # 2h, doubling for every earlier ban within 48h (like fail2ban's
          # bantime.increment), up to 32h. The count includes decisions of any
          # kind; each round is a captcha + a ban, so it goes in pairs.
          name = "pangolin_ban";
          filters = [ "Alert.Remediation == true && Alert.GetScope() == 'Ip' && Alert.GetScenario() == 'vps/pangolin-bf-ban'" ];
          decisions = [{ type = "ban"; duration = "2h"; }];
          duration_expr =
            let n = "GetDecisionsSinceCount(Alert.GetValue(), '48h')"; in
            "${n} < 2 ? '2h' : ${n} < 4 ? '4h' : ${n} < 6 ? '8h' : ${n} < 8 ? '16h' : '32h'";
          on_success = "break";
        }
        {
          name = "default_ip_remediation";
          filters = [ "Alert.Remediation == true && Alert.GetScope() == 'Ip'" ];
          decisions = [{ type = "ban"; duration = "4h"; }];
          # Repeat offenders: 4h, 8h, 12h, ... profiles.yaml is written via a
          # tmpfiles argument, which expands specifiers: %% for a literal %.
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

  # cscli fails on a missing CAPI credentials file, even `cscli capi register`
  # can't load its config: start with an empty one (setup registers if empty).
  systemd.tmpfiles.rules = [
    # Z: hand over files a former DynamicUser run left behind.
    "d /var/lib/crowdsec 0755 ${config.services.crowdsec.user} ${config.services.crowdsec.group} -"
    "Z /var/lib/crowdsec - ${config.services.crowdsec.user} ${config.services.crowdsec.group} -"
    "Z /var/lib/crowdsec-firewall-bouncer-register - ${config.services.crowdsec.user} ${config.services.crowdsec.group} -"
    "f ${stateDir}/online_api_credentials.yaml 0600 ${config.services.crowdsec.user} ${config.services.crowdsec.group} -"
    # The former module linked localConfig items as <store hash>-<name>.yaml.
    # Those stay in /etc/crowdsec next to the new N-nixos-generated.yaml and
    # would load every parser/scenario twice, or dangle after a GC.
    "r /etc/crowdsec/scenarios/${storeHash}-scenario.yaml"
    "r /etc/crowdsec/parsers/s01-parse/${storeHash}-parsers-s01-parse.yaml"
    "r /etc/crowdsec/parsers/s02-enrich/${storeHash}-parsers-s02-enrich.yaml"
  ];
  # settings land in /etc/crowdsec via tmpfiles, outside the unit: without this
  # a changed parser/scenario/profile only takes effect on the next boot.
  systemd.services.crowdsec.restartTriggers = [ (builtins.toJSON config.services.crowdsec.settings) ];

  networking.firewall.extraCommands = ''
    iptables -I nixos-fw -p tcp -s 172.16.0.0/12 -m multiport --dports ${toString lapiPort},${toString appsecPort} -j nixos-fw-accept
  '';
  networking.firewall.extraStopCommands = ''
    iptables -D nixos-fw -p tcp -s 172.16.0.0/12 -m multiport --dports ${toString lapiPort},${toString appsecPort} -j nixos-fw-accept || true
  '';

  services.crowdsec-firewall-bouncer = {
    enable = true;
    settings = {
      mode = "iptables";
      api_url = "http://127.0.0.1:${toString lapiPort}";
      # DOCKER-USER sees DNATed traffic to published container ports, which
      # never passes INPUT.
      iptables_chains = [ "INPUT" "DOCKER-USER" ];
    };
  };
  # DOCKER-USER only exists once dockerd has set up its chains. Upstream
  # requires the register unit without ordering after it: the API key may not
  # exist yet.
  systemd.services.crowdsec-firewall-bouncer = {
    after = [ "docker.service" "crowdsec-firewall-bouncer-register.service" ];
    wants = [ "docker.service" ];
  };

  # Key files + captcha/ban pages for the traefik plugin (*File options), in
  # one dir mounted into traefik at /crowdsec (pangolin.nix). Copies, not sops
  # symlinks: those don't resolve inside the container.
  systemd.services.crowdsec-traefik-files = {
    description = "Files for the CrowdSec Traefik bouncer plugin";
    wantedBy = [ "docker.service" ];
    before = [ "docker.service" ];
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
    };
    script = ''
      install -d -m 0700 ${traefikDir}
      install -m 0400 ${secrets.crowdsec-traefik-bouncer-key.path} ${traefikDir}/lapi-key
      install -m 0400 ${secrets.turnstile-site-key.path} ${traefikDir}/captcha-site-key
      install -m 0400 ${secrets.turnstile-secret-key.path} ${traefikDir}/captcha-secret-key
      install -m 0444 ${captchaHtml} ${traefikDir}/captcha.html
      install -m 0444 ${banHtml} ${traefikDir}/ban.html
    '';
  };

  # Register the traefik bouncer with the key from sops (re-added on each run,
  # so rotating the secret just works).
  systemd.services.crowdsec-traefik-bouncer-register = {
    description = "Register the CrowdSec Traefik bouncer";
    wantedBy = [ "multi-user.target" ];
    after = [ "crowdsec.service" ];
    requires = [ "crowdsec.service" ];
    path = [ config.services.crowdsec.package ];
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
      # cscli is the plain binary now; as root it would leave root-owned sqlite
      # WAL files the crowdsec user can't write.
      User = config.services.crowdsec.user;
      Group = config.services.crowdsec.group;
      LoadCredential = "key:${secrets.crowdsec-traefik-bouncer-key.path}";
    };
    script = ''
      key=$(cat "$CREDENTIALS_DIRECTORY/key")
      cscli bouncers delete traefik >/dev/null 2>&1 || true
      cscli bouncers add traefik --key "$key" >/dev/null
    '';
  };
}
