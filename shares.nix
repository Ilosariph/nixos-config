{ pkgs, ... }:
{
  environment.systemPackages = [ pkgs.cifs-utils ];
  fileSystems."/mnt/projects" = { # Your desired mount point
    device = "//192.168.1.148/p";
    fsType = "cifs";
    options = let
      automount_opts = "x-systemd.automount,noauto,x-systemd.idle-timeout=60,x-systemd.device-timeout=5s,x-systemd.mount-timeout=5s";
    in [
      "${automount_opts},credentials=/etc/nixos/smb-p"
      "uid=1000"
      "gid=100"
      "vers=3.0"
    ];
  };
  fileSystems."/mnt/simon" = { # Your desired mount point
    device = "//192.168.1.148/simon_data";
    fsType = "cifs";
    options = let
      automount_opts = "x-systemd.automount,noauto,x-systemd.idle-timeout=60,x-systemd.device-timeout=5s,x-systemd.mount-timeout=5s";
    in [
      "${automount_opts},credentials=/etc/nixos/smb-s"
      "uid=1000"
      "gid=100"
      "vers=3.0"
    ];
  };
}
