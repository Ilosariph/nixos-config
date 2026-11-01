{ config, lib, pkgs, ... }:
# Vikunja API proxy for Hermes: full reads, writes only on Hermes-labelled tasks.
#
# Vikunja runs on a VPS (https). Hermes must never hold the API token: everything in the
# hermes container (env, mounts) is readable by the agent itself. So a small service on
# evo (./vikunja-proxy.py) holds the token and injects it server-side; Hermes calls
# http://127.0.0.1:${port}/api/v1/... with no credentials.
#
#   - bound to 127.0.0.1, not opened in the firewall -> evo-local only (hermes is --network=host)
#   - GET/HEAD under /api/v1/ pass through
#   - writes: an explicit allowlist (create/update/delete task, add/remove label), and every
#     write to an existing task first re-reads it and requires the `${label}` label.
#     Created tasks get the label automatically. Login/token/bulk/project/... endpoints: 403.
#   - so Hermes can only touch tasks Simon labelled `${label}` (or that it created); removing
#     the label in Vikunja revokes access at once. Hermes itself cannot remove that label.
#
# Host: config.dotfiles.private.domains.vikunja (private.nix, bare hostname of the
# instance, e.g. tasks.example.com).
# Secret (sops):
#   vikunja-api-token : Vikunja API token (tk_...), Settings -> API Tokens. Needs read on
#                       projects/tasks/labels plus tasks create/update/delete, task labels
#                       create/delete and labels create. Nothing else (no projects write,
#                       no bulk) so the upstream token stays as narrow as Vikunja allows.
let
  port = 9121;
  label = "Hermes";
  vikunjaHost = config.dotfiles.private.domains.vikunja;
in
lib.mkIf config.dotfiles.services.hermes.enable {
  sops.secrets."vikunja-api-token" = { restartUnits = [ "vikunja-proxy.service" ]; };

  systemd.services.vikunja-proxy = {
    description = "Vikunja API proxy for Hermes on 127.0.0.1:${toString port}";
    wantedBy = [ "multi-user.target" ];
    wants = [ "network-online.target" ];
    after = [ "network-online.target" "sops-nix.service" ];
    environment = {
      VIKUNJA_URL = "https://${vikunjaHost}";
      VIKUNJA_PROXY_PORT = toString port;
      VIKUNJA_LABEL = label;
      SSL_CERT_FILE = "/etc/ssl/certs/ca-certificates.crt";
    };
    serviceConfig = {
      ExecStart = "${pkgs.python3.interpreter} ${./vikunja-proxy.py}";
      # Root-only sops secret handed to the unprivileged unit as $CREDENTIALS_DIRECTORY/token.
      LoadCredential = "token:${config.sops.secrets."vikunja-api-token".path}";
      Restart = "on-failure";
      RestartSec = 5;
      DynamicUser = true;
      ProtectSystem = "strict";
      ProtectHome = true;
      PrivateTmp = true;
      NoNewPrivileges = true;
    };
  };

  environment.etc."hermes/SOUL.md".text = ''

    # Vikunja (tasks)

    Simon's Vikunja task manager (v2.x) is at http://127.0.0.1:${toString port}/api/v1/ — no auth needed, auth is added upstream. Use `curl -sS`. You can read everything, but only change tasks labelled `${label}`; any other write is rejected (403) by the proxy, don't try to work around it.

    Writes (JSON body, `-H 'Content-Type: application/json'`):
    - create: `PUT /api/v1/projects/<project_id>/tasks` `{"title": ..., "description": ..., "due_date": "2026-11-05T18:00:00Z", "priority": 0-5}` → gets the `${label}` label automatically
    - update: `POST /api/v1/tasks/<id>` with only the fields to change, e.g. `{"done": true}` (others are kept)
    - delete: `DELETE /api/v1/tasks/<id>`
    - labels: `PUT /api/v1/tasks/<id>/labels` `{"label_id": n}`, `DELETE /api/v1/tasks/<id>/labels/<label_id>` (not the `${label}` label)
    Settable fields: title, description, done, due_date, start_date, end_date, priority, percent_done, repeat_after, repeat_mode, reminders, hex_color, is_favorite, project_id (update only). Anything else → 400.

    Endpoints: `/api/v1/projects`, `/api/v1/tasks`, `/api/v1/tasks/<id>`, `/api/v1/projects/<id>/tasks`, `/api/v1/labels`. There is no `/tasks/all` (it is parsed as a task id → "Invalid model provided").

    Filtering: `filter=` takes a query expression (URL-encoded), e.g. `/api/v1/tasks?filter=done+%3D+false&sort_by=due_date&order_by=asc` (`done = false`), or `done = false && project = 1`, `due_date < now+7d`. Fields: done, priority, percent_done, due_date, start_date, end_date, done_at, assignees, labels, project, reminders, created, updated (snake_case — camelCase gives 400); operators `= != > >= < <= like in`, joined by `&&` / `||`.

    Pagination: max 50 items per page. Always check the `X-Pagination-Total-Pages` response header (`curl -sS -D-`) and fetch `&page=2`, `&page=3`, … until done — never report counts from the first page alone.
  '';
}
