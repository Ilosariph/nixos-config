{ pkgs, config, ... }:
{
  services.ollama = {
    enable = true;
    package = pkgs.ollama-rocm;
    host = "127.0.0.1";
    port = 11435;  # internal; nginx proxies port 11434 with API key auth
    rocmOverrideGfx = "11.5.0";  # Radeon 8060S (Strix Halo - RDNA 3.5)
    environmentVariables = {
      HSA_OVERRIDE_GFX_VERSION = "11.5.0";
      OLLAMA_DEBUG = "1";
    };
  };

  services.open-webui = {
    enable = true;
    host = "127.0.0.1";
    port = 8080;
    environment = {
      OLLAMA_BASE_URL = "http://127.0.0.1:11435";  # bypass proxy; direct access
    };
  };

  # Reverse proxy: enforces OpenAI-style Bearer token on port 11434.
  # The map block is loaded from a secrets file to keep the key out of /nix/store.
  # See README.md for setup instructions.
  services.nginx = {
    enable = true;
    appendHttpConfig = ''
      include /etc/nixos/secrets/ollama-nginx-auth.conf;
    '';
    virtualHosts."ollama-proxy" = {
      listen = [{ addr = "0.0.0.0"; port = 11434; ssl = false; }];
      locations."/" = {
        proxyPass = "http://127.0.0.1:11435";
        extraConfig = ''
          if ($ollama_auth_ok = 0) {
            return 401;
          }
        '';
      };
    };
  };

  networking.firewall.allowedTCPPorts = [ 11434 4001 ];
}
