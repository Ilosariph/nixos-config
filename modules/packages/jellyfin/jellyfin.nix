{ ... }: {
  flake.nixosModules.jellyfin = { config, lib, ... }:
    let
      cfg = config.dotfiles.services.jellyfin;
      basePath = "${config.dotfiles.programs.docker.basePath}/jellyfin";
    in
    lib.mkIf cfg.enable {
      virtualisation.oci-containers.containers.jellyfin = {
        image = "jellyfin/jellyfin";
        hostname = "jellyfin.internal";
        user = "1000:1000";
        ports = [
          "8096:8096/tcp"
          "7359:7359/udp"
        ];
        volumes = [
          "${basePath}/config:/config"
          "${basePath}/cache:/cache"
          "/mnt/arr/media:/media"
        ];
        environment = {
          JELLYFIN_PublishedServerUrl = cfg.publishedServerUrl;
          PUID = "1000";
          PGID = "1000";
        };
        extraOptions = [
          "--add-host=host.docker.internal:host-gateway"
        ];
      };
    };
}
