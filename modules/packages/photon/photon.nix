{ ... }: {
  flake.nixosModules.photon = { config, lib, ... }:
    let
      cfg = config.dotfiles.services.photon;
      # Not under docker basePath: the planet index (~60 GB) is re-downloadable and would bloat the docker-configs backup
      dataPath = "/var/lib/photon";
    in
    lib.mkIf cfg.enable {
      # Photon-compatible geocoder for Dawarich (PHOTON_API_HOST). Loopback only, exposed via Pangolin newt.
      virtualisation.oci-containers.containers.photon = {
        image = "rtuszik/photon-docker:latest";
        ports = [ "127.0.0.1:2322:2322" ];
        volumes = [ "${dataPath}:/photon/data" ];
        environment = {
          REGION = "planet";
          # SEQUENTIAL replaces the index in place (brief downtime); PARALLEL would need 2x disk
          UPDATE_STRATEGY = "SEQUENTIAL";
          UPDATE_INTERVAL = "30d";
        };
      };

      systemd.tmpfiles.rules = [ "d ${dataPath} 0755 root root -" ];
    };
}
