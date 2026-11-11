{ config, lib, pkgs, ... }:
let
  user = config.dotfiles.user.name;
in
{
  # Static config only; NetworkManager would try DHCP on eno1 next to it.
  networking.networkmanager.enable = lib.mkForce false;

  # Docker-published ports bypass this via the DOCKER chain. Containers with
  # host networking don't, so their ports (private.nix) have to be opened here.
  networking.firewall =
    let
      fw = config.dotfiles.private.nucserver.firewall;
    in
    {
      allowedTCPPorts = fw.tcp;
      allowedTCPPortRanges = fw.tcpRanges;
      allowedUDPPorts = fw.udp;
    };

  services.openssh.settings = {
    PermitRootLogin = "no";
    PasswordAuthentication = false;
    KbdInteractiveAuthentication = false;
  };

  boot.loader.grub.useOSProber = lib.mkForce false;
  boot.loader.grub.gfxmodeEfi = lib.mkForce "auto";
  # disko adds the disk with the EF02 partition to grub.devices itself; drop
  # dotfiles.bootloader.grubDevice so it isn't listed twice.
  boot.loader.grub.device = lib.mkForce "";

  # The firmware sometimes hangs in POST after a warm reset (after longer
  # uptime; kernel reboot= methods and BIOS settings didn't help), cold boots
  # never do. So every reboot becomes a power cycle: last thing before the
  # reset, with file systems synced and read-only, set an RTC alarm and power
  # off instead. Needs BIOS "Wake System from S5" off, its own schedule
  # replaces the alarm. Messages at <0> so they show on the console.
  systemd.shutdown.cold-reboot = pkgs.writeShellScript "cold-reboot" ''
    log() { echo "<0>cold-reboot: $*" > /dev/kmsg; }
    # $1 should be the verb but arrives empty (systemd 262). PID 1 is
    # systemd-shutdown here, its command line has the verb too.
    verb=''${1:-}
    if [ -z "$verb" ]; then
      mapfile -d "" -t args < /proc/1/cmdline
      for a in "''${args[@]:1}"; do
        case "$a" in reboot|poweroff|halt|kexec|exit) verb=$a; break ;; esac
      done
    fi
    log "verb '$verb' (\$1 '$1', pid 1: ''${args[*]:-})"
    [ "$verb" = reboot ] || exit 0
    echo 0 > /sys/class/rtc/rtc0/wakealarm || log "clearing alarm failed"
    if ! echo +60 > /sys/class/rtc/rtc0/wakealarm; then
      log "setting alarm failed, warm reset"; exit 0
    fi
    log "alarm $(< /sys/class/rtc/rtc0/wakealarm), now $(< /sys/class/rtc/rtc0/since_epoch), powering off"
    echo o > /proc/sysrq-trigger || log "sysrq failed"
    # Power-off runs async; if it never happens, fall through to the reset.
    ${pkgs.coreutils}/bin/sleep 30
    log "still running after power-off request, warm reset"
  '';

  services.thermald.enable = true;
  services.fstrim.enable = true;
  zramSwap.enable = true;

  # Like Ubuntu: dockerd stops the containers (clean DB shutdown) when it stops.
  # With live-restore they outlive it and systemd-shutdown kills them after 90s.
  virtualisation.docker.liveRestore = false;
  # Mount the media share before containers bind it; a bind of the bare
  # automount point wouldn't show the mount inside the container. Wants, so
  # docker still starts with the NAS down.
  systemd.services.docker = {
    wants = [ "mnt-arr.mount" ];
    after = [ "mnt-arr.mount" ];
  };

  # The pre-command dumps the database; a missed run fires right after boot.
  systemd.services.backup-immich.after = [ "docker.service" ];

  users.users.${user} = {
    # Containers run as PUID 1000 and the restored files are owned by 1000.
    uid = 1000;
    extraGroups = [ "docker" ];
    # Root login is off, so sudo and the console need a password from the
    # start. Value: `mkpasswd -m yescrypt`.
    hashedPasswordFile = config.sops.secrets.simon-password-hash.path;
  };

  # The Immich postgres dir is owned by uid 999 (postgres in the image). NixOS
  # hands out system uids from 999 down, so claim it: otherwise whichever
  # service gets 999 first could read the database files on the host.
  users.users.immich-postgres = {
    uid = 999;
    isSystemUser = true;
    group = "immich-postgres";
  };
  users.groups.immich-postgres.gid = 999;

  sops.secrets = {
    simon-password-hash.neededForUsers = true;
    smb-arr = { };
    smb-immich = { };
    smb-docker-backup = { };
  };

  environment.systemPackages = with pkgs; [
    jq
    sqlite
  ];
}
