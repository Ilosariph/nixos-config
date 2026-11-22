{ ... }: {
  # DigiKey Product Search MCP server for Claude Code
  # (https://github.com/bengineer19/digikey_mcp, reviewed at the pinned rev:
  # only talks to api.digikey.com). Registered through home-manager's
  # programs.claude-code.mcpServers (package = null: claude-code itself stays
  # in base.nix), so its tools show up as mcp__plugin_hm_digikey__*.
  #
  # Credentials: sops secret `digikey-mcp-env` in the host file, dotenv format:
  #   CLIENT_ID=...
  #   CLIENT_SECRET=...
  flake.nixosModules.digikey-mcp = { config, lib, pkgs, ... }:
    let
      src = pkgs.fetchFromGitHub {
        owner = "bengineer19";
        repo = "digikey_mcp";
        rev = "b2e26b95a06c288c4ed7842ae77b97413e535058";
        hash = "sha256-Vt7ES8uI/TEmJvnpeP6YHRHydy86E5f9C1AwLimk9Zs=";
      };

      python = pkgs.python3.withPackages (ps: [ ps.mcp ps.requests ps.python-dotenv ]);

      # Upstream fetches one OAuth token at startup (DigiKey tokens expire after
      # ~10 min → every call 401s afterwards) and inverts USE_SANDBOX. Patch:
      # fetch lazily, refresh after 9 min; USE_SANDBOX=true means sandbox.
      # fastmcp is broken in nixpkgs (needs mcp < 2) → official SDK's MCPServer,
      # same @tool()/run() API. Locale defaults to the Swiss site in CHF
      # (DIGIKEY_SITE / DIGIKEY_CURRENCY in the secret override it).
      server = pkgs.runCommand "digikey-mcp-server.py" { } ''
        cp ${src}/digikey_mcp_server.py $out
        substituteInPlace $out \
          --replace-fail 'import os' $'import os\nimport time' \
          --replace-fail 'from fastmcp import FastMCP' 'from mcp.server.mcpserver import MCPServer as FastMCP' \
          --replace-fail 'os.getenv("USE_SANDBOX", "true").lower() == "false"' 'os.getenv("USE_SANDBOX", "false").lower() == "true"' \
          --replace-fail 'access_token = get_access_token()' $'_token = [None, 0.0]\n\ndef _access_token():\n    if _token[0] is None or time.time() - _token[1] > 540:\n        _token[0], _token[1] = get_access_token(), time.time()\n    return _token[0]' \
          --replace-fail '"Authorization": f"Bearer {access_token}"' '"Authorization": f"Bearer {_access_token()}"' \
          --replace-fail '"X-DIGIKEY-Locale-Site": "US"' '"X-DIGIKEY-Locale-Site": os.getenv("DIGIKEY_SITE", "CH")' \
          --replace-fail '"X-DIGIKEY-Locale-Currency": "USD"' '"X-DIGIKEY-Locale-Currency": os.getenv("DIGIKEY_CURRENCY", "CHF")'
      '';

      digikey-mcp = pkgs.writeShellApplication {
        name = "digikey-mcp";
        text = ''
          set -a
          # shellcheck source=/dev/null
          . ${config.sops.secrets.digikey-mcp-env.path}
          set +a
          exec ${python}/bin/python3 -I ${server}
        '';
      };
    in
    lib.mkIf config.dotfiles.programs.digikeyMcp.enable {
      sops.secrets.digikey-mcp-env = {
        owner = config.dotfiles.user.name;
        mode = "0400";
      };

      home-manager.users.${config.dotfiles.user.name} = { ... }: {
        programs.claude-code = {
          enable = true;
          package = null;
          mcpServers.digikey = {
            type = "stdio";
            command = lib.getExe digikey-mcp;
          };
        };
      };
    };
}
