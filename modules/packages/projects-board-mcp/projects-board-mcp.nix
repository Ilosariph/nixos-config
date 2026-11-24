{ ... }: {
  # Projects board MCP (~/Projects/projects-board, runs on the VPS behind Pangolin).
  # Remote Streamable-HTTP server, registered through home-manager's
  # programs.claude-code.mcpServers → tools show up as mcp__plugin_hm_board__*.
  # The bearer token never enters the store: headersHelper reads it from sops
  # at connect time.
  #
  # Host: config.dotfiles.private.domains.projectsBoard (private.nix, bare hostname).
  # Secret (sops, shared.yaml):
  #   projects-board-mcp-token : the board's MCP_TOKEN
  flake.nixosModules.projects-board-mcp = { config, lib, pkgs, ... }:
    let
      host = config.dotfiles.private.domains.projectsBoard or null;
      headers = pkgs.writeShellApplication {
        name = "projects-board-mcp-headers";
        runtimeInputs = [ pkgs.jq ];
        text = ''
          jq -cn --rawfile t ${config.sops.secrets.projects-board-mcp-token.path} \
            '{Authorization: ("Bearer " + ($t | rtrimstr("\n")))}'
        '';
      };
    in
    lib.mkIf config.dotfiles.programs.projectsBoardMcp.enable {
      assertions = [{
        assertion = host != null;
        message = "dotfiles.programs.projectsBoardMcp needs domains.projectsBoard in private.nix";
      }];

      sops.secrets.projects-board-mcp-token = {
        sopsFile = config.dotfiles.sops.sharedSecretsFile;
        owner = config.dotfiles.user.name;
        mode = "0400";
      };

      home-manager.users.${config.dotfiles.user.name} = { ... }: {
        programs.claude-code = {
          enable = true;
          package = null;
          mcpServers.board = {
            type = "http";
            url = "https://${toString host}/mcp";
            headersHelper = lib.getExe headers;
          };
        };
      };
    };
}
