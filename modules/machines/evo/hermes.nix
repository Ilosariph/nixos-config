{ config, lib, ... }:
# Nous Research Hermes agent on evo.
#
# Runs as an oci-container (podman, the repo default) with Discord as the input channel
# and a basic-auth web dashboard on :9119. Talks to the local llama.cpp servers
# (see ./ollama.nix) over the host network:
#   - default/coding model : Qwen3.6-27B  @ 127.0.0.1:8081
#   - manual-switch model  : Gemma4-26B   @ 127.0.0.1:8082
#
# Hermes does not auto-route models per task, so Qwen3.6 is the default; Gemma4 is
# selectable in-chat (/model) or via the dashboard.
#
# Secrets (sops): hermes-discord-token, hermes-dashboard-password.
let
  cfg = config.dotfiles.services.hermes;
  user = config.dotfiles.user.name;
  configDir = "/home/${user}/.hermes";
  configSrc = config.sops.templates."hermes-config".path;
  gitCredsSrc = config.sops.templates."hermes-git-credentials".path;
in
lib.mkIf cfg.enable {
  sops.secrets."hermes-discord-token" = { mode = "0400"; restartUnits = [ "podman-hermes.service" ]; };
  sops.secrets."hermes-discord-allowed-users" = { mode = "0400"; restartUnits = [ "podman-hermes.service" ]; };
  sops.secrets."hermes-discord-channel" = { mode = "0400"; restartUnits = [ "podman-hermes.service" ]; };
  sops.secrets."hermes-dashboard-username" = { mode = "0400"; restartUnits = [ "podman-hermes.service" ]; };
  sops.secrets."hermes-dashboard-password" = { mode = "0400"; restartUnits = [ "podman-hermes.service" ]; };
  # Forgejo access token for the `hermes` account (scoped to its fork). Lets the agent push
  # to the local git forge over the host network; it never sees GitHub credentials.
  sops.secrets."forgejo-hermes-token" = { mode = "0400"; restartUnits = [ "podman-hermes.service" ]; };

  # Environment file for the container (secrets + dashboard/discord config).
  #
  # Discord access control lives here (not in config.yaml) — env keys are the
  # schema-verified surface (see Hermes messaging docs):
  #   - ALLOWED_USERS  : comma-separated user-ID allowlist (sops, multiple accounts)
  #   - ALLOWED_CHANNELS: restrict bot to the home channel only
  #   - HOME_CHANNEL   : default channel for automated/job delivery
  #   - REQUIRE_MENTION=false : respond without @mention in the allowed channel
  sops.templates."hermes-env" = {
    mode = "0400";
    content = ''
      DISCORD_BOT_TOKEN=${config.sops.placeholder."hermes-discord-token"}
      DISCORD_ALLOWED_USERS=${config.sops.placeholder."hermes-discord-allowed-users"}
      DISCORD_ALLOWED_CHANNELS=${config.sops.placeholder."hermes-discord-channel"}
      DISCORD_HOME_CHANNEL=${config.sops.placeholder."hermes-discord-channel"}
      DISCORD_REQUIRE_MENTION=false
      HERMES_DASHBOARD=1
      HERMES_DASHBOARD_HOST=0.0.0.0
      HERMES_DASHBOARD_PORT=9119
      HERMES_DASHBOARD_BASIC_AUTH_USERNAME=${config.sops.placeholder."hermes-dashboard-username"}
      HERMES_DASHBOARD_BASIC_AUTH_PASSWORD=${config.sops.placeholder."hermes-dashboard-password"}
    '';
  };

  # git credential store for the Forgejo forge (reached over the host network on loopback).
  # Consumed via the credential helper configured in /opt/data/.gitconfig (see below);
  # git finds that config through GIT_CONFIG_GLOBAL set on the container.
  sops.templates."hermes-git-credentials" = {
    mode = "0400";
    content = ''
      http://hermes:${config.sops.placeholder."forgejo-hermes-token"}@127.0.0.1:3000
    '';
  };

  # config.yaml — model backend, folder access, Discord channel policy.
  sops.templates."hermes-config" = {
    mode = "0444";
    content = ''
      # Hermes config — managed by NixOS/sops-nix. Do not edit on disk.
      # Both models are served by one llama-swap endpoint (:8081, see ./ollama.nix), so
      # /v1/models lists both and they appear in the picker automatically. qwen3.6-27b is
      # the default; select gemma4-26b via /model or the dashboard.
      model:
        provider: custom
        model: qwen3.6-27b
        base_url: http://127.0.0.1:8081/v1
        api_key: "none"
      # backend: local -> commands run directly inside this container (Debian 13,
      # has git/apt/python3/curl). The old `docker` backend spawned a sibling
      # container per command and needs a Docker daemon in-container -> we run under
      # podman with no docker socket, so every execute_code/git call failed with
      # "Docker command is available but 'docker version' failed". The project dir
      # is already bind-mounted at the container level (see volumes below),
      # so no docker_volumes needed.
      terminal:
        backend: local
      # MCP servers — launched by Hermes as stdio subprocesses inside this
      # container (uvx/uv/npx/python3 are all on PATH, Debian 13). Tools register
      # as mcp_<name>_<tool>. Edit + /reload-mcp in chat to pick up changes without
      # a container restart.
      mcp_servers:
        nixos:
          command: uvx
          args: ["mcp-nixos"]
      # Discord access control is configured via env vars in hermes-env
      # (DISCORD_ALLOWED_USERS / _CHANNELS / _HOME_CHANNEL / _REQUIRE_MENTION).
    '';
  };

  # SOUL.md — persistent agent identity / system prompt (slot #1). Loaded every
  # session from $HERMES_HOME/SOUL.md (== /opt/data in the container). Hermes seeds
  # a default and never overwrites, so we manage the file ourselves and install it
  # over the seed. Non-secret -> plain string, no sops.
  environment.etc."hermes/SOUL.md".text = ''
    You are Hermes Agent, an intelligent AI assistant created by Nous Research. You are helpful, knowledgeable, and direct. You assist users with a wide range of tasks including answering questions, writing and editing code, analyzing information, creative work, and executing actions via your tools. You communicate clearly, admit uncertainty when appropriate, and prioritize being genuinely useful over being verbose unless otherwise directed below. Be targeted and efficient in your exploration and investigations.

    # Response style

    Drop: articles, filler (just/really/basically), pleasantries (sure/happy to), hedging. Fragments OK. Short synonyms. No tool-call narration. Technical terms exact. Code blocks unchanged. Errors quoted verbatim. No self-reference. No preamble.

    Abbreviate prose words (DB/auth/config/req/res/fn/impl), strip conjunctions, arrows for causality (X → Y). Never abbreviate code symbols, function names, API names, error strings.

    Pattern: [thing] [action] [reason]. [next step].

    Elaborate the following: security warnings, irreversible action confirmations, multi-step sequences where fragment order risks misread, compression creates technical ambiguity. Resume short mode after.

    # Git workflow (nixos-config)

    Local Forgejo forge, not GitHub. You have no GitHub access. Repos:
      - upstream (read-only mirror of GitHub): http://127.0.0.1:3000/simon/nixos-config.git
      - your fork (push here):                 http://127.0.0.1:3000/hermes/nixos-config.git

    Steps: clone your fork into /opt/data/projects, branch off origin/main, commit, push branch
    to your fork, open a PR against simon/nixos-config:main via the Forgejo API/UI. Never commit
    to main directly. Credentials are pre-configured (git just works over http on 127.0.0.1:3000).
    Simon reviews the PR and forwards it to GitHub — you do not.
  '';

  # git global config for the container: point the credential helper at the sops-rendered
  # store file and set the commit identity. Non-secret (the token lives in .git-credentials).
  environment.etc."hermes/gitconfig".text = ''
    [credential]
        helper = store --file=/opt/data/.git-credentials
    [user]
        name = hermes
        email = hermes@${config.dotfiles.services.forgejo.domain}
    [init]
        defaultBranch = main
    [safe]
        directory = *
  '';

  # Copy the sops-rendered config + SOUL.md into the writable data dir before the container starts.
  systemd.services.hermes-config-sync = {
    description = "Sync Hermes sops config into data dir";
    before = [ "podman-hermes.service" ];
    wantedBy = [ "podman-hermes.service" ];
    after = [ "sops-nix.service" ];
    serviceConfig = {
      Type = "oneshot";
      ExecStart = "/bin/sh -c 'install -Dm644 ${configSrc} ${configDir}/config.yaml && install -Dm644 /etc/hermes/SOUL.md ${configDir}/SOUL.md && install -Dm644 /etc/hermes/gitconfig ${configDir}/.gitconfig && install -Dm600 ${gitCredsSrc} ${configDir}/.git-credentials'";
    };
  };

  # Dedicated CIFS mount of the `p` share's `hermes/` subfolder, mounted 0777 so the
  # hermes container (runs as root, uid 0) can write. The regular `dotfiles.shares`
  # mount of /mnt/projects stays uid=1000,file_mode=0755 (owner-only write) and is
  # left untouched — file_mode is a per-mount option, so a second mount is the only way
  # to widen perms for hermes without affecting the other folders on that share.
  fileSystems."/mnt/hermes-projects" = {
    device = "//192.168.1.148/p/hermes";
    fsType = "cifs";
    options = [
      "x-systemd.automount,noauto,x-systemd.idle-timeout=60,x-systemd.device-timeout=5s,x-systemd.mount-timeout=5s"
      "credentials=/etc/nixos/smb-p"
      "uid=1000"
      "gid=100"
      "file_mode=0777"
      "dir_mode=0777"
      # noperm: skip client-side permission checks. The container runs as root
      # (uid 0) but CIFS forceuid pins every file to uid 1000, so git's chmod on
      # loose objects failed with EPERM for the non-owner. noperm makes the client
      # stop enforcing perms locally (safe: this is a dedicated hermes-only mount).
      "noperm"
      "vers=3.0"
    ];
  };

  # Pre-create host dirs for the volume mounts.
  systemd.tmpfiles.rules = [
    "d ${configDir}  0755 ${user} users - -"
  ];

  virtualisation.oci-containers.containers.hermes = {
    image = "nousresearch/hermes-agent:latest";
    cmd = [ "gateway" "run" ];
    environmentFiles = [ config.sops.templates."hermes-env".path ];
    # Point git at the global config we install into /opt/data (credential helper + identity),
    # without disturbing the container's HOME. Container path, not the host configDir.
    environment.GIT_CONFIG_GLOBAL = "/opt/data/.gitconfig";
    # HERMES_WRITE_SAFE_ROOT=/opt/data is baked into the image (also HERMES_HOME),
    # so the agent can only write under /opt/data. Mount the projects dir *inside*
    # that root (/opt/data/projects) so writes pass the guard. The source is the
    # dedicated 0777 CIFS mount above (not /mnt/projects) so container-root can write.
    # Podman overlays the nested mount onto the subdir of the configDir mount.
    volumes = [
      "${configDir}:/opt/data"
      "/mnt/hermes-projects:/opt/data/projects"
    ];
    ports = [ "9119:9119" ];
    extraOptions = [
      "--network=host"
      "--no-healthcheck"
    ];
  };

  networking.firewall.allowedTCPPorts = [ 9119 ];
}
