{ ... }: {
  # finit has no automount units (x-systemd.automount), and fstab mounts run
  # before NetworkManager is up. Each share is a finit task that mounts once
  # the default route exists instead.
  flake.finixModules.shares = { config, pkgs, lib, utils, ... }:
    let
      mkTask = share:
        let server = if share.server != null then share.server else config.dotfiles.sharesDefaultServer;
        in lib.nameValuePair "mount-share-${utils.escapePath share.mountPoint}" {
          description = "mount //${server}/${share.share} on ${share.mountPoint}";
          conditions = [ "net/route/default" ];
          path = [ pkgs.util-linux pkgs.cifs-utils pkgs.coreutils ];
          script = ''
            mkdir -p ${share.mountPoint}
            mountpoint -q ${share.mountPoint} || mount -t cifs \
              -o credentials=${share.credentials},uid=${toString share.uid},gid=${toString share.gid},vers=3.0 \
              //${server}/${share.share} ${share.mountPoint}
          '';
        };
    in lib.mkIf (config.dotfiles.shares != []) {
      environment.systemPackages = [ pkgs.cifs-utils ];
      finit.tasks = lib.listToAttrs (map mkTask config.dotfiles.shares);
    };
}
