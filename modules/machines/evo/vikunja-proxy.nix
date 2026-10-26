{ config, lib, ... }:
# Read-only Vikunja API proxy for Hermes.
#
# Vikunja runs on a VPS (https). Hermes must be able to read tasks without ever holding
# the API token: everything in the hermes container (env, mounts) is readable by the
# agent itself. So nginx on evo holds the token and injects it server-side; Hermes calls
# http://127.0.0.1:${port}/api/v1/... with no credentials.
#
#   - bound to 127.0.0.1, not opened in the firewall -> evo-local only (hermes is --network=host)
#   - GET/HEAD only (limit_except) -> no writes, no login/token endpoints (all POST/PUT)
#   - only /api/v1/ is proxied, everything else 404
#
# Host: config.dotfiles.private.domains.vikunja (private.nix, bare hostname of the
# instance, e.g. tasks.example.com).
# Secret (sops):
#   vikunja-api-token : Vikunja API token (tk_...). Create it in Vikunja under
#                       Settings -> API Tokens with read-only permissions only, so writes
#                       fail upstream too even if this proxy were misconfigured.
let
  port = 9121;
  vikunjaHost = config.dotfiles.private.domains.vikunja;
  # nginx needs a resolver for a variable proxy_pass. Variable (not literal) upstream so
  # nginx still starts when the VPS/DNS is unreachable at boot (the comfyui vhost shares it).
  # IPv4 only: evo has no IPv6 default route (v6 resolvers/AAAA upstreams -> "Network is unreachable").
  resolvers = lib.filter (ns: !lib.hasInfix ":" ns) config.networking.nameservers;
in
lib.mkIf config.dotfiles.services.hermes.enable {
  sops.secrets."vikunja-api-token" = { };

  # Rendered nginx snippet holding the token; readable by nginx only.
  sops.templates."vikunja-proxy.conf" = {
    owner = "nginx";
    group = "nginx";
    mode = "0400";
    restartUnits = [ "nginx.service" ];
    content = ''
      set $vikunja_host "${vikunjaHost}";
      proxy_pass https://$vikunja_host;
      proxy_set_header Host $vikunja_host;
      proxy_set_header Authorization "Bearer ${config.sops.placeholder."vikunja-api-token"}";
      proxy_ssl_server_name on;
      proxy_ssl_name $vikunja_host;
      proxy_ssl_verify on;
      # default depth 1 rejects leaf -> intermediate -> root chains (error 20)
      proxy_ssl_verify_depth 3;
      proxy_ssl_trusted_certificate /etc/ssl/certs/ca-certificates.crt;
    '';
  };

  services.nginx = {
    enable = true;
    virtualHosts."vikunja-ro" = {
      listen = [
        {
          addr = "127.0.0.1";
          inherit port;
        }
      ];
      locations."/api/v1/".extraConfig = ''
        resolver ${lib.concatStringsSep " " resolvers} valid=300s ipv6=off;
        limit_except GET { deny all; }
        proxy_set_header Cookie "";
        include ${config.sops.templates."vikunja-proxy.conf".path};
      '';
      locations."/".return = "404";
    };
  };

  environment.etc."hermes/SOUL.md".text = ''

    # Vikunja (tasks, read-only)

    Simon's Vikunja task manager (v2.x) is readable at http://127.0.0.1:${toString port}/api/v1/ — no auth needed, auth is added upstream. GET only; writes are rejected. Use `curl -sS`.

    Endpoints: `/api/v1/projects`, `/api/v1/tasks`, `/api/v1/tasks/<id>`, `/api/v1/projects/<id>/tasks`, `/api/v1/labels`. There is no `/tasks/all` (it is parsed as a task id → "Invalid model provided").

    Filtering: `filter=` takes a query expression (URL-encoded), e.g. `/api/v1/tasks?filter=done+%3D+false&sort_by=due_date&order_by=asc` (`done = false`), or `done = false && project = 1`, `due_date < now+7d`. Fields: done, priority, percent_done, due_date, start_date, end_date, done_at, assignees, labels, project, reminders, created, updated (snake_case — camelCase gives 400); operators `= != > >= < <= like in`, joined by `&&` / `||`.

    Pagination: max 50 items per page. Always check the `X-Pagination-Total-Pages` response header (`curl -sS -D-`) and fetch `&page=2`, `&page=3`, … until done — never report counts from the first page alone.
  '';
}
