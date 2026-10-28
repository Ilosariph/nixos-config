{ ... }: {
  flake.nixosModules.seerr = { config, lib, ... }:
    let
      cfg = config.dotfiles.services.seerr;
      # Dir name predates this module (old jellyseerr compose stack); covered by the docker-configs backup on evo
      basePath = "${config.dotfiles.programs.docker.basePath}/jellyseer";
    in
    lib.mkIf cfg.enable {
      virtualisation.oci-containers.containers.seerr = {
        image = "ghcr.io/seerr-team/seerr:latest";
        ports = [ "5055:5055" ];
        volumes = [ "${basePath}/config:/app/config" ];
        environment = {
          TZ = config.time.timeZone;
          PORT = "5055";
        };
        extraOptions = [ "--init" "--no-healthcheck" ];
      };

      # Seerr runs as node (uid 1000), jellyseerr ran as root and left root-owned files behind
      systemd.services.podman-seerr.preStart = lib.mkBefore ''
        chown -R 1000:100 ${basePath}/config
      '';
    };
}
