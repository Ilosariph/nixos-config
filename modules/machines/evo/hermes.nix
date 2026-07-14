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
in
lib.mkIf cfg.enable {
  sops.secrets."hermes-discord-token" = { mode = "0400"; restartUnits = [ "podman-hermes.service" ]; };
  sops.secrets."hermes-discord-allowed-users" = { mode = "0400"; restartUnits = [ "podman-hermes.service" ]; };
  sops.secrets."hermes-discord-channel" = { mode = "0400"; restartUnits = [ "podman-hermes.service" ]; };
  sops.secrets."hermes-dashboard-username" = { mode = "0400"; restartUnits = [ "podman-hermes.service" ]; };
  sops.secrets."hermes-dashboard-password" = { mode = "0400"; restartUnits = [ "podman-hermes.service" ]; };

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
      # and /data are already bind-mounted at the container level (see volumes below),
      # so no docker_volumes needed.
      terminal:
        backend: local
      # Discord access control is configured via env vars in hermes-env
      # (DISCORD_ALLOWED_USERS / _CHANNELS / _HOME_CHANNEL / _REQUIRE_MENTION).
    '';
  };

  # Copy the sops-rendered config into the writable data dir before the container starts.
  systemd.services.hermes-config-sync = {
    description = "Sync Hermes sops config into data dir";
    before = [ "podman-hermes.service" ];
    wantedBy = [ "podman-hermes.service" ];
    after = [ "sops-nix.service" ];
    serviceConfig = {
      Type = "oneshot";
      ExecStart = "/bin/sh -c 'install -Dm644 ${configSrc} ${configDir}/config.yaml'";
    };
  };

  # Pre-create host dirs for the volume mounts.
  systemd.tmpfiles.rules = [
    "d ${configDir}          0755 ${user} users - -"
    "d /mnt/projects/hermes  0755 ${user} users - -"
    "d /home/${user}/data    0755 ${user} users - -"
  ];

  virtualisation.oci-containers.containers.hermes = {
    image = "nousresearch/hermes-agent:latest";
    cmd = [ "gateway" "run" ];
    environmentFiles = [ config.sops.templates."hermes-env".path ];
    volumes = [
      "${configDir}:/opt/data"
      "/mnt/projects/hermes:/workspace/projects"
      "/home/${user}/data:/data"
    ];
    ports = [ "9119:9119" ];
    extraOptions = [
      "--network=host"
      "--no-healthcheck"
    ];
  };

  networking.firewall.allowedTCPPorts = [ 9119 ];
}
