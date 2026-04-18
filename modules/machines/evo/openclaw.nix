{ config, lib, ... }:

let
  cfg        = config.dotfiles.services.openclaw;
  user       = config.dotfiles.user.name;
  configDir  = "/home/${user}/openclaw";
  secretPath = config.sops.templates."openclaw-config".path;
in
lib.mkIf cfg.enable {
  sops.secrets."openclaw-discord-token" = {
    mode = "0400";
  };

  sops.secrets."ollama-bearer-token" = {
    mode = "0400";
  };

  sops.templates."openclaw-discord-env" = {
    mode    = "0400";
    content = "DISCORD_BOT_TOKEN=${config.sops.placeholder."openclaw-discord-token"}";
  };

  sops.templates."openclaw-config" = {
    mode  = "0444";
    content = ''
      // OpenClaw config — managed by NixOS/sops-nix. Do not edit on disk.
      {
        gateway: {
          mode: "local",
        },
        models: {
          providers: {
            ollama: {
              apiKey: "${config.sops.placeholder."ollama-bearer-token"}",
              baseUrl: "http://127.0.0.1:11434",
              api: "ollama",
              models: [
                { id: "qwen3.5:122b",           name: "qwen3.5:122b",           reasoning: true,  input: ["text"], cost: { input: 0, output: 0, cacheRead: 0, cacheWrite: 0 }, contextWindow: 262144, maxTokens: 32768 },
                { id: "qwen3-coder-next:latest", name: "qwen3-coder-next:latest", reasoning: false, input: ["text"], cost: { input: 0, output: 0, cacheRead: 0, cacheWrite: 0 }, contextWindow: 262144, maxTokens: 32768 },
                { id: "qwen3.5:27b",             name: "qwen3.5:27b",             reasoning: true,  input: ["text"], cost: { input: 0, output: 0, cacheRead: 0, cacheWrite: 0 }, contextWindow: 262144, maxTokens: 32768 },
                { id: "qwen2.5:72b",             name: "qwen2.5:72b",             reasoning: false, input: ["text"], cost: { input: 0, output: 0, cacheRead: 0, cacheWrite: 0 }, contextWindow: 131072, maxTokens: 32768 },
                { id: "gpt-oss:120b",            name: "gpt-oss:120b",            reasoning: true,  input: ["text"], cost: { input: 0, output: 0, cacheRead: 0, cacheWrite: 0 }, contextWindow: 131072, maxTokens: 32768 },
              ],
            },
          },
        },
        agents: {
          defaults: {
            model: "ollama/qwen3.5:27b",
          },
        },
        channels: {
          discord: {
            enabled: true,
            token: {
              source: "env",
              provider: "default",
              id: "DISCORD_BOT_TOKEN",
            },
            groupPolicy: "allowlist",
            guilds: {
              "1097230214758666281": {
                requireMention: false,
                channels: {
                  "1494767063179198734": {
                    enabled: true,
                  },
                },
              },
            },
          },
        },
      }
    '';
  };

  # Copy the sops-rendered config into the writable config dir before container starts.
  systemd.services.openclaw-config-sync = {
    description = "Sync openclaw sops config to config dir";
    before   = [ "podman-openclaw-gateway.service" ];
    wantedBy = [ "podman-openclaw-gateway.service" ];
    after    = [ "sops-nix.service" ];
    serviceConfig = {
      Type      = "oneshot";
      ExecStart = "/bin/sh -c 'cp ${secretPath} ${configDir}/config.json5 && chmod 644 ${configDir}/config.json5'";
    };
  };

  virtualisation.oci-containers.containers.openclaw-gateway = {
    image   = "ghcr.io/openclaw/openclaw:latest";
    cmd     = [ "node" "dist/index.js" "gateway" ];
    environment    = { OPENCLAW_CONFIG_PATH = "/home/node/.openclaw/config.json5"; };
    environmentFiles = [ config.sops.templates."openclaw-discord-env".path ];
    volumes = [
      "${configDir}:/home/node/.openclaw"
      "/mnt/projects/openclaw:/mnt/projects"
      "/home/${user}/data:/data"
    ];
    extraOptions = [
      "--network=host"
      "--no-healthcheck"
    ];
  };
}
