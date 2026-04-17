{ pkgs, config, lib, openclawPkg, ... }:

let
  cfg       = config.dotfiles.services.openclaw;
  user      = config.dotfiles.user.name;
  ollamaUrl = "http://127.0.0.1:11435";
  configDir = "/home/${user}/.config/openclaw";
  configPath = "${configDir}/config.json5";

  # Compute the sandbox closure at build time: openclaw + cfg.rootPaths.
  # Only these store paths are visible inside bwrap — no rest of /nix/store.
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
      --bind        /tmp                      /tmp                    \
      --bind        /run/user/1000            /run/user/1000          \
      --ro-bind     "${configDir}"            "${configDir}"          \
      --ro-bind     /home/${user}/data        /home/${user}/data      \
      --bind        /mnt/projects             /mnt/projects           \
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
    owner = user;
    mode  = "0400";
  };

  # Write the OpenClaw config.json5 with the Discord token injected at runtime.
  sops.templates."openclaw-config" = {
    owner = user;
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

  home-manager.users.${user} = { config, lib, ... }: {
    programs.openclaw = {
      enable = true;
      # Config path is set via OPENCLAW_CONFIG_PATH env var in the bwrap wrapper.
    };

    # Override the systemd user service installed by the HM module to wrap the
    # binary in bubblewrap. Only the openclaw closure + cfg.rootPaths are visible.
    systemd.user.services.openclaw = {
      Service = {
        ExecStart = lib.mkForce
          "${openclawBwrap} ${config.programs.openclaw.package}/bin/openclaw";
        Environment = lib.mkForce [
          "OPENCLAW_CONFIG_PATH=${configPath}"
        ];
        NoNewPrivileges = true;
      };
    };
  };
}
