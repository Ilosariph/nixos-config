{ config, lib, pkgs, ... }:
# Projects board MCP proxy for Hermes (~/Projects/projects-board, runs on the VPS).
#
# Same idea as ./vikunja-proxy.nix: Hermes must never hold the board token (everything
# in the hermes container is readable by the agent), so ./board-proxy.py on evo holds it
# and injects it; Hermes uses http://127.0.0.1:${port}/mcp with no credentials
# (registered in ./hermes.nix mcp_servers → tools mcp_board_*).
#   - bound to 127.0.0.1, not opened in the firewall -> evo-local only (hermes is --network=host)
#   - delete tools are hidden + refused: Hermes closes items with state=dropped instead
#
# Host: config.dotfiles.private.domains.projectsBoard (private.nix).
# Secret (sops, hosts/evo.yaml): projects-board-mcp-token (the board's MCP_TOKEN).
let
  port = 9123;
  deny = [ "delete_project" "delete_item" ];
in
lib.mkIf config.dotfiles.services.hermes.enable {
  sops.secrets."projects-board-mcp-token" = {
    restartUnits = [ "board-proxy.service" ];
  };

  systemd.services.board-proxy = {
    description = "Projects board MCP proxy for Hermes on 127.0.0.1:${toString port}";
    wantedBy = [ "multi-user.target" ];
    wants = [ "network-online.target" ];
    after = [ "network-online.target" "sops-nix.service" ];
    environment = {
      BOARD_URL = "https://${config.dotfiles.private.domains.projectsBoard}/mcp";
      BOARD_PROXY_PORT = toString port;
      BOARD_DENY_TOOLS = lib.concatStringsSep "," deny;
      SSL_CERT_FILE = "/etc/ssl/certs/ca-certificates.crt";
    };
    serviceConfig = {
      ExecStart = "${pkgs.python3.interpreter} ${./board-proxy.py}";
      # Root-only sops secret handed to the unprivileged unit as $CREDENTIALS_DIRECTORY/token.
      LoadCredential = "token:${config.sops.secrets."projects-board-mcp-token".path}";
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

    # Projects board

    Simon's projects board (parallel hardware/software projects, shown on his phone) is available as MCP tools `mcp_board_*`. Model: projects (status, summary, current_work, progress) with items of kind todo (action for Simon), blocker (waiting on delivery/measurement/decision/person, with `meantime` work), next (planned step), idea; plus a dated log. Start with `overview`.
    - Ideas Simon adds from his phone without a project land in project `inbox`. When asked to sort them: move each to the matching project (`update_item` id=… project=<slug>), or if it is a new project idea, create the project with `upsert_project` status=idea and move it there. Leave it in inbox if unsure and say why.
    - Deleting is not available: close items with `update_item` state=done or state=dropped.
    - Keep titles short (phone view); details go in `detail`.
  '';
}
