{ pkgs, config, lib, openclawPkg, ... }:

let
  cfg        = config.dotfiles.services.openclaw;
  user       = config.dotfiles.user.name;
  ollamaUrl  = "http://127.0.0.1:11435";
  configDir  = "/etc/openclaw";
  configPath = "${configDir}/config.json5";

  # Only the openclaw-gateway closure + cfg.rootPaths are visible in the sandbox.
  sandboxClosure = pkgs.closureInfo {
    rootPaths = [ openclawPkg ] ++ cfg.rootPaths;
  };

  sandboxPath = lib.makeBinPath cfg.rootPaths;

  openclawBwrap = pkgs.writeShellScript "openclaw-bwrap" ''
    set -euo pipefail
    OPENCLAW_BIN="''${1:?Usage: openclaw-bwrap <binary> [args...]}"
    shift

    STORE_ARGS=()
    while IFS= read -r p; do
      STORE_ARGS+=(--ro-bind "$p" "$p")
    done < ${sandboxClosure}/store-paths

    exec ${pkgs.bubblewrap}/bin/bwrap \
      "''${STORE_ARGS[@]}"                                            \
      --ro-bind-try /etc/resolv.conf          /etc/resolv.conf        \
      --ro-bind-try /etc/ssl/certs            /etc/ssl/certs          \
      --ro-bind     "${configDir}"            "${configDir}"          \
      --ro-bind     /home/${user}/data        /home/${user}/data      \
      --bind        /mnt/projects             /mnt/projects           \
      --bind        /tmp                      /tmp                    \
      --proc        /proc                                             \
      --dev         /dev                                              \
      --unshare-all                                                   \
      --share-net                                                     \
      --new-session                                                   \
      --die-with-parent                                               \
      --setenv PATH "${sandboxPath}"                                  \
      --setenv OPENCLAW_CONFIG_PATH "${configPath}"                   \
      -- "$OPENCLAW_BIN" "$@"
  '';
in
lib.mkIf cfg.enable {
  sops.secrets."openclaw-discord-token" = {
    mode = "0400";
  };

  # Write config.json5 with the Discord token injected at activation time.
  sops.templates."openclaw-config" = {
    mode  = "0400";
    path  = configPath;
    content = ''
      // OpenClaw config — managed by NixOS/sops-nix. Do not edit on disk.
      {
        llm: {
          provider: "ollama",
          baseUrl: "${ollamaUrl}",
          model: "llama3.1:8b",
        },
        channels: [
          {
            type: "discord",
            token: "${config.sops.placeholder."openclaw-discord-token"}",
            // After creating the bot in the Discord developer portal, set:
            // guildId:   "YOUR_GUILD_ID",
            // channelId: "YOUR_CHANNEL_ID",
          },
        ],
        agent: {
          name: "openclaw-evo",
          workdir: "/mnt/projects",
        },
      }
    '';
  };

  # Configure the openclaw-gateway NixOS module (imported in evo.nix).
  services.openclaw = {
    enable      = true;
    configFile  = configPath;
  };

  # Wrap the gateway system service in bubblewrap.
  systemd.services.openclaw-gateway.serviceConfig = {
    ExecStart = lib.mkForce
      "${openclawBwrap} ${openclawPkg}/bin/openclaw-gateway";
    NoNewPrivileges = true;
  };
}
