# Pangolin + Gerbil + Traefik as docker containers declared here (replaces
# /docker/important/Pangolin/docker-compose.yml). Config files are generated;
# state (db, key, letsencrypt, GeoLite2) stays in /docker/important/Pangolin/config
# so restic keeps backing it up. Update = bump a tag below + deploy.
{ config, lib, pkgs, ... }:
let
  p = config.dotfiles.private.vps.pangolin;
  yaml = pkgs.formats.yaml { };

  images = {
    pangolin = "docker.io/fosrl/pangolin:ee-1.24.0";
    gerbil = "docker.io/fosrl/gerbil:1.5.2";
    traefik = "docker.io/traefik:v3.7.13";
  };
  # v1.8.0 fails Traefik's plugin integrity check, stay on v1.7.0 until fixed.
  badgerVersion = "v1.7.0";
  crowdsecPluginVersion = "v1.8.1";

  stateDir = "/docker/important/Pangolin/config";
  stateCondition = "${stateDir}/db/db.sqlite";
  apiDomain = "api.${p.dashboardDomain}";
  # CrowdSec LAPI/AppSec on the host (crowdsec.nix), reached over docker0.
  crowdsecHost = "172.17.0.1";

  traefikStatic = {
    api = {
      insecure = true;
      dashboard = true;
    };
    providers = {
      http = {
        endpoint = "http://pangolin:3001/api/v1/traefik-config";
        pollInterval = "5s";
      };
      file.filename = "/etc/traefik/dynamic_config.yml";
    };
    experimental.plugins = {
      badger = {
        moduleName = "github.com/fosrl/badger";
        version = badgerVersion;
      };
      crowdsec = {
        moduleName = "github.com/maxlerebourg/crowdsec-bouncer-traefik-plugin";
        version = crowdsecPluginVersion;
      };
    };
    log = {
      level = "INFO";
      format = "common";
    };
    # stdout -> journald -> crowdsec (CONTAINER_NAME=traefik)
    accessLog = {
      format = "json";
      fields.headers = {
        defaultMode = "drop";
        names.User-Agent = "keep";
      };
    };
    certificatesResolvers.letsencrypt.acme = {
      dnsChallenge.provider = "cloudflare";
      email = p.letsEncryptEmail;
      storage = "/letsencrypt/acme.json";
      caServer = "https://acme-v02.api.letsencrypt.org/directory";
    };
    entryPoints = {
      web.address = ":80";
      websecure = {
        address = ":443";
        transport.respondingTimeouts.readTimeout = "30m";
        http = {
          tls.certResolver = "letsencrypt";
          middlewares = [ "crowdsec@file" ];
          encodedCharacters = {
            allowEncodedSlash = true;
            allowEncodedQuestionMark = true;
          };
        };
      };
    };
    serversTransport.insecureSkipVerify = true;
    ping.entryPoint = "web";
  };

  traefikDynamic = {
    http = {
      middlewares = {
        badger.plugin.badger.disableForwardAuth = true;
        redirect-to-https.redirectScheme.scheme = "https";
        crowdsec.plugin.crowdsec = {
          enabled = true;
          logLevel = "INFO";
          # Stream mode + never block on LAPI/AppSec outages: a crowdsec
          # restart must not take every site down.
          crowdsecMode = "stream";
          updateIntervalSeconds = 15;
          updateMaxFailure = -1;
          crowdsecLapiScheme = "http";
          crowdsecLapiHost = "${crowdsecHost}:8080";
          crowdsecLapiKeyFile = "/crowdsec/lapi-key";
          crowdsecAppsecEnabled = true;
          crowdsecAppsecHost = "${crowdsecHost}:7422";
          crowdsecAppsecFailureBlock = true;
          crowdsecAppsecUnreachableBlock = false;
          crowdsecAppsecBodyLimit = 10485760;
          captchaProvider = "turnstile";
          captchaSiteKeyFile = "/crowdsec/captcha-site-key";
          captchaSecretKeyFile = "/crowdsec/captcha-secret-key";
          captchaHTMLFilePath = "/crowdsec/captcha.html";
          captchaGracePeriodSeconds = 1800;
          banHTMLFilePath = "/crowdsec/ban.html";
          # No forwardedHeadersTrustedIPs: traefik is reached directly (no CDN),
          # so client-sent X-Forwarded-For must not be trusted.
          clientTrustedIPs = [ "10.0.0.0/8" "172.16.0.0/12" "192.168.0.0/16" ]
            ++ (config.dotfiles.private.vps.trustedIPs or [ ]);
        };
      };

      routers = {
        main-app-router-redirect = {
          rule = "Host(`${p.dashboardDomain}`)";
          service = "next-service";
          entryPoints = [ "web" ];
          middlewares = [ "redirect-to-https" "badger" ];
        };
        int-api-router = {
          rule = "Host(`${apiDomain}`)";
          service = "int-api-service";
          entryPoints = [ "websecure" ];
          tls.certResolver = "letsencrypt";
        };
        # Next.js (everything except API and WebSocket paths). Also requests
        # the wildcard certs for every domain resources live on.
        next-router = {
          rule = "Host(`${p.dashboardDomain}`) && !PathPrefix(`/api/v1`)";
          service = "next-service";
          entryPoints = [ "websecure" ];
          middlewares = [ "badger" ];
          tls = {
            certResolver = "letsencrypt";
            domains = map (d: { main = d; sans = [ "*.${d}" ]; }) p.wildcardDomains;
          };
        };
        api-router = {
          rule = "Host(`${p.dashboardDomain}`) && PathPrefix(`/api/v1`)";
          service = "api-service";
          entryPoints = [ "websecure" ];
          middlewares = [ "badger" ];
          tls.certResolver = "letsencrypt";
        };
        ws-router = {
          rule = "Host(`${p.dashboardDomain}`)";
          service = "api-service";
          entryPoints = [ "websecure" ];
          middlewares = [ "badger" ];
          tls.certResolver = "letsencrypt";
        };
      };

      services = {
        next-service.loadBalancer.servers = [{ url = "http://pangolin:3002"; }];
        api-service.loadBalancer.servers = [{ url = "http://pangolin:3000"; }];
        int-api-service.loadBalancer.servers = [{ url = "http://pangolin:3003"; }];
      };
    };

    tcp.serversTransports = {
      pp-transport-v1.proxyProtocol.version = 1;
      pp-transport-v2.proxyProtocol.version = 2;
    };
  };

  # Real files (not store symlinks), so the dir can be bind-mounted as is.
  traefikConf = pkgs.runCommand "pangolin-traefik-conf" { } ''
    mkdir $out
    cp ${yaml.generate "traefik_config.yml" traefikStatic} $out/traefik_config.yml
    cp ${yaml.generate "dynamic_config.yml" traefikDynamic} $out/dynamic_config.yml
  '';

  pangolinConfig = {
    gerbil = {
      start_port = 51820;
      base_endpoint = p.dashboardDomain;
    };
    app = {
      dashboard_url = "https://${p.dashboardDomain}";
      log_level = "info";
      # crowdsec.nix parses these (vps/pangolin-bf)
      log_failed_attempts = true;
      telemetry.anonymous_usage = true;
    };
    domains.domain1 = {
      base_domain = p.baseDomain;
      prefer_wildcard_cert = true;
    };
    server = {
      secret = config.sops.placeholder.pangolin-server-secret;
      trust_proxy = 2;
      cors = {
        origins = [ "https://${p.dashboardDomain}" ];
        methods = [ "GET" "POST" "PUT" "DELETE" "PATCH" ];
        allowed_headers = [ "X-CSRF-Token" "Content-Type" ];
        credentials = false;
      };
      maxmind_db_path = "./config/GeoLite2-Country.mmdb";
    };
    flags = {
      require_email_verification = false;
      disable_signup_without_invite = true;
      disable_user_create_org = false;
      allow_raw_resources = true;
      enable_integration_api = true;
    };
  };

  ensureNetwork = name: args: {
    description = "Docker network ${name}";
    after = [ "docker.service" ];
    requires = [ "docker.service" ];
    path = [ config.virtualisation.docker.package ];
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
    };
    script = ''
      docker network inspect ${name} >/dev/null 2>&1 || docker network create ${args} ${name}
    '';
  };
  networkUnits = [ "docker-network-pangolin.service" "docker-network-proxy.service" ];
in
{
  sops.secrets.pangolin-server-secret = { };
  sops.secrets.cloudflare-dns-api-token = { };

  # JSON is valid YAML; templates are the only way to splice in secrets.
  sops.templates."pangolin-config.yml" = {
    content = builtins.toJSON pangolinConfig;
    restartUnits = [ "docker-pangolin.service" ];
  };
  sops.templates."traefik.env" = {
    content = "CLOUDFLARE_DNS_API_TOKEN=${config.sops.placeholder.cloudflare-dns-api-token}\n";
    restartUnits = [ "docker-traefik.service" ];
  };

  # `proxy` is the shared network every /docker/compose stack joins as external.
  systemd.services.docker-network-proxy = ensureNetwork "proxy" "";
  systemd.services.docker-network-pangolin = ensureNetwork "pangolin" "--ipv6";

  virtualisation.oci-containers.backend = "docker";
  virtualisation.oci-containers.containers = {
    pangolin = {
      image = images.pangolin;
      networks = [ "pangolin" "proxy" ];
      ports = [ "127.0.0.1:3003:3003" ];
      volumes = [
        "${stateDir}:/app/config"
        "${config.sops.templates."pangolin-config.yml".path}:/app/config/config.yml:ro"
      ];
      extraOptions = [
        "--memory=1g"
        "--memory-reservation=256m"
        "--health-cmd=curl -f http://localhost:3001/api/v1/"
        "--health-interval=10s"
        "--health-timeout=10s"
        "--health-retries=15"
      ];
    };

    gerbil = {
      image = images.gerbil;
      networks = [ "pangolin" "proxy" ];
      cmd = [
        "--reachableAt=http://gerbil:3004"
        "--generateAndSaveKeyTo=/var/config/key"
        "--remoteConfig=http://pangolin:3001/api/v1/"
      ];
      volumes = [ "${stateDir}:/var/config" ];
      capabilities = {
        NET_ADMIN = true;
        SYS_MODULE = true;
      };
      # Traefik shares gerbil's network namespace, so its ports live here.
      ports = [
        "51820:51820/udp"
        "21820:21820/udp"
        "443:443"
        "80:80"
      ];
    };

    traefik = {
      image = images.traefik;
      dependsOn = [ "gerbil" ];
      cmd = [ "--configFile=/etc/traefik/traefik_config.yml" ];
      environmentFiles = [ config.sops.templates."traefik.env".path ];
      volumes = [
        "${traefikConf}:/etc/traefik:ro"
        "${stateDir}/letsencrypt:/letsencrypt"
        "/run/crowdsec-traefik:/crowdsec:ro"
      ];
      extraOptions = [ "--network=container:gerbil" ];
    };
  };

  systemd.services = {
    # On a fresh install /docker is empty until vps-migrate-restore ran: starting
    # now would init a new DB/key/acme.json that the restore then half-overwrites
    # (e.g. a stale db.sqlite-wal next to the restored db). Skip until state exists.
    docker-pangolin = {
      unitConfig.ConditionPathExists = stateCondition;
      after = networkUnits;
      requires = networkUnits;
      # Compose's `depends_on: service_healthy`: only report started once the
      # healthcheck passes, so gerbil/traefik (ordered after) find the API up.
      postStart = ''
        for _ in $(seq 1 150); do
          [ "$(docker inspect -f '{{.State.Health.Status}}' pangolin 2>/dev/null)" = healthy ] && exit 0
          sleep 2
        done
        echo "pangolin not healthy after 300s, starting dependents anyway"
      '';
    };
    # Ordering only (not dependsOn): a pangolin upgrade shouldn't bounce the
    # WireGuard tunnels.
    docker-gerbil = {
      unitConfig.ConditionPathExists = stateCondition;
      after = networkUnits ++ [ "docker-pangolin.service" ];
      requires = networkUnits;
      wants = [ "docker-pangolin.service" ];
    };
    # Lives in gerbil's netns: must go down and up with it.
    docker-traefik = {
      unitConfig.ConditionPathExists = stateCondition;
      bindsTo = [ "docker-gerbil.service" ];
      after = [ "docker-pangolin.service" "crowdsec-traefik-files.service" ];
      wants = [ "docker-pangolin.service" ];
      requires = [ "crowdsec-traefik-files.service" ];
    };
  };
}
