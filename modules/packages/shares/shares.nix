{ ... }: {
  flake.nixosModules.shares = { config, pkgs, lib, ... }:
    let
      automount_opts = "x-systemd.automount,noauto,x-systemd.idle-timeout=60,x-systemd.device-timeout=5s,x-systemd.mount-timeout=5s";
    in {
      environment.systemPackages = lib.mkIf (config.dotfiles.shares != []) [ pkgs.cifs-utils ];

      fileSystems = lib.listToAttrs (map (share:
        let server = if share.server != null then share.server else config.dotfiles.sharesDefaultServer;
        in {
          name = share.mountPoint;
          value = {
            device = "//${server}/${share.share}";
            fsType = "cifs";
            options = [
              "${automount_opts},credentials=${share.credentials}"
              "uid=${toString share.uid}"
              "gid=${toString share.gid}"
              "vers=3.0"
            ];
          };
        }) config.dotfiles.shares);
    };
}
