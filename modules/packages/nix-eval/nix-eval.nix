{ ... }: {
  # Localhost-only HTTP endpoint that lets Hermes (evo, --network=host) check that its
  # working copy of nixos-config evaluates/builds. Bound to 127.0.0.1 and not opened in
  # the firewall -> only reachable from evo itself; bearer token keeps other local users out.
  # Hermes sees the repo at /opt/data/projects/nixos-config; this service reads the same
  # files via the host mount (cfg.repoDir).
  #
  # Secret (sops): hermes-nix-eval-token. Also injected into the Hermes container as
  # NIX_EVAL_TOKEN (see modules/machines/evo/hermes.nix).
  flake.nixosModules.nix-eval = { config, lib, pkgs, ... }:
    let
      cfg = config.dotfiles.services.nixEval;
    in
    lib.mkIf cfg.enable {
      sops.secrets."hermes-nix-eval-token" = {
        mode = "0400";
        restartUnits = [ "nix-eval.service" ];
      };

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
        path = [ config.nix.package ];
        environment = {
          NIX_EVAL_REPO_DIR = cfg.repoDir;
          NIX_EVAL_HOSTS = lib.concatStringsSep "," cfg.hosts;
          NIX_EVAL_PORT = toString cfg.port;
          NIX_EVAL_TIMEOUT = toString cfg.timeout;
          # nix needs a writable HOME for its eval/fetcher cache.
          HOME = "/var/cache/nix-eval";
        };
        serviceConfig = {
          ExecStart = "${pkgs.python3.interpreter} ${./server.py}";
          EnvironmentFile = config.sops.templates."nix-eval-env".path;
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
