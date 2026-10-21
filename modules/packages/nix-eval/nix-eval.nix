{ ... }: {
  # Localhost-only HTTP endpoint that lets Hermes (evo, --network=host) check that its
  # working copy of nixos-config evaluates/builds. Bound to 127.0.0.1 and not opened in
  # the firewall -> only reachable from evo itself; bearer token keeps other local users out.
  # Hermes sees the repo at /opt/data/projects/nixos-config; this service reads the same
  # files via the host mount (cfg.repoDir).
  #
  # Secrets (sops): hermes-nix-eval-token. Also injected into the Hermes container as
  # NIX_EVAL_TOKEN (see modules/machines/evo/hermes.nix).
  # nix-secrets-deploy-key: read-only GitHub deploy key for the private nix-secrets
  # flake input, which nix fetches over git+ssh (see docs/secrets.md).
  flake.nixosModules.nix-eval = { config, lib, pkgs, ... }:
    let
      cfg = config.dotfiles.services.nixEval;
    in
    lib.mkIf cfg.enable {
      sops.secrets."hermes-nix-eval-token" = {
        mode = "0400";
        restartUnits = [ "nix-eval.service" ];
      };

      sops.secrets."nix-secrets-deploy-key" = {
        mode = "0400";
        restartUnits = [ "nix-eval.service" ];
      };

      # Pin GitHub's host key so the non-interactive fetch never hits a TOFU prompt.
      programs.ssh.knownHosts."github.com".publicKey =
        "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIOMqqnkVzrm0SdG6UOoqKLsabgH5C9okWi0dh2l9GKJl";

      sops.templates."nix-eval-env" = {
        mode = "0400";
        content = ''
          NIX_EVAL_TOKEN=${config.sops.placeholder."hermes-nix-eval-token"}
        '';
      };

      systemd.services.nix-eval = {
        description = "Nix config eval/build endpoint for Hermes on 127.0.0.1:${toString cfg.port}";
        wantedBy = [ "multi-user.target" ];
        after = [ "network.target" "sops-nix.service" ];
        # git + ssh: nix shells out to them for the git+ssh nix-secrets input.
        path = [ config.nix.package pkgs.git pkgs.openssh ];
        environment = {
          NIX_EVAL_REPO_DIR = cfg.repoDir;
          NIX_EVAL_HOSTS = lib.concatStringsSep "," cfg.hosts;
          NIX_EVAL_PORT = toString cfg.port;
          NIX_EVAL_TIMEOUT = toString cfg.timeout;
          # nix needs a writable HOME for its eval/fetcher cache.
          HOME = "/var/cache/nix-eval";
          # %d = $CREDENTIALS_DIRECTORY (LoadCredential below).
          GIT_SSH_COMMAND = "ssh -i %d/nix-secrets-deploy-key -o IdentitiesOnly=yes -o BatchMode=yes";
        };
        serviceConfig = {
          ExecStart = "${pkgs.python3.interpreter} ${./server.py}";
          EnvironmentFile = config.sops.templates."nix-eval-env".path;
          # The DynamicUser can't read the root-owned sops file; systemd hands it a
          # private copy instead.
          LoadCredential = "nix-secrets-deploy-key:${config.sops.secrets."nix-secrets-deploy-key".path}";
          Restart = "on-failure";
          RestartSec = 5;
          # Unprivileged throwaway user: evaluating Hermes-edited code must not be able to
          # read root-only files (e.g. /run/secrets). Builds still go through nix-daemon.
          DynamicUser = true;
          CacheDirectory = "nix-eval";
          ProtectHome = true;
          PrivateTmp = true;
          NoNewPrivileges = true;
        };
      };
    };
}
