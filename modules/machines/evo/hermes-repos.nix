{ config, lib, pkgs, ... }:
# Fetch-only GitHub access for Hermes, without Hermes holding any credential.
#
# git-proxy (./git-proxy.py, DynamicUser, 127.0.0.1 only) holds a GitHub token and forwards
# only git-upload-pack (clone/fetch/pull) to github.com; git-receive-pack (push) and anything
# else -> 403. The container's /etc/gitconfig rewrites https://github.com/ to the proxy, so
# Hermes clones as usual and keeps full local write access (branches, reset, commits) in
# its own clones under /opt/data/projects/github (hermes share). Never a push: proxy refuses it, token is read-only anyway.
#
#   - token only in $CREDENTIALS_DIRECTORY of git-proxy (LoadCredential), never in the container
#   - bound to 127.0.0.1, not opened in the firewall (hermes is --network=host)
#   - which private repos are reachable = the token's repo selection
#   - GET /_repos: names of readable repos (only API call the proxy makes, nothing passed through)
#
# Secret (sops): hermes-repos-token : fine-grained GitHub PAT, "Only select repositories",
#   Repository permissions: Contents read-only (Metadata read-only is implied). Nothing else.
let
  port = 9122;
  # Subdir of the hermes CIFS share (/mnt/hermes-projects -> /opt/data/projects in the container).
  reposDir = "/opt/data/projects/github";
  gitconfig = pkgs.writeText "hermes-gitconfig" ''
    [url "http://127.0.0.1:${toString port}/"]
    	insteadOf = https://github.com/
    	insteadOf = git@github.com:
    	insteadOf = ssh://git@github.com/
    # CIFS forces uid 1000 on every file, container git runs as root -> "dubious ownership".
    [safe]
    	directory = *
    # Fallback identity so commit/stash work; a global ~/.gitconfig in the container wins.
    [user]
    	name = Hermes
    	email = hermes@evo.invalid
  '';
in
lib.mkIf (config.dotfiles.services.hermes.enable && config.dotfiles.services.hermes.githubProxy.enable) {
  sops.secrets."hermes-repos-token" = { restartUnits = [ "git-proxy.service" ]; };

  systemd.services.git-proxy = {
    description = "Fetch-only GitHub proxy for Hermes on 127.0.0.1:${toString port}";
    wantedBy = [ "multi-user.target" ];
    wants = [ "network-online.target" ];
    after = [ "network-online.target" "sops-nix.service" ];
    environment = {
      GIT_PROXY_PORT = toString port;
      SSL_CERT_FILE = "/etc/ssl/certs/ca-certificates.crt";
    };
    serviceConfig = {
      ExecStart = "${pkgs.python3.interpreter} ${./git-proxy.py}";
      LoadCredential = "token:${config.sops.secrets."hermes-repos-token".path}";
      Restart = "on-failure";
      RestartSec = 5;
      DynamicUser = true;
      ProtectSystem = "strict";
      ProtectHome = true;
      PrivateTmp = true;
      NoNewPrivileges = true;
    };
  };

  virtualisation.oci-containers.containers.hermes.volumes = [ "${gitconfig}:/etc/gitconfig:ro" ];

  environment.etc."hermes/SOUL.md".text = ''

    # GitHub repos

    Simon's GitHub user is `Ilosariph`; a bare repo name means `Ilosariph/<repo>`. `curl -sS http://127.0.0.1:${toString port}/_repos` lists every repo you can clone (`<owner>/<repo> private|public`); a private repo not listed there is not accessible, don't retry.

    `git clone https://github.com/<owner>/<repo>` works for those private repos too: GitHub URLs go through a local fetch-only proxy, auth added upstream. Always clone into `${reposDir}/<repo>` (`mkdir -p ${reposDir}` first), not elsewhere. Locally do anything (branches, commits, reset, checkout); fetch/pull work. Push is impossible (proxy → 403) and you have no GitHub API access, so no PRs. Don't try to work around it; tell Simon which branch/commit to look at instead.
  '';
}
