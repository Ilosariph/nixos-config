{ ... }: {
  flake.nixosModules.fail2ban = { config, lib, ... }:
    let
      cfg = config.dotfiles.services.fail2ban;
    in
    {
      services.fail2ban.enable = cfg.enable;

      # Never ban the local network. Deploys run from mainpc over SSH, and a
      # single agent hiccup burns through maxretry (3) in one attempt --
      # sshd then refuses port 22 and locks the deploying machine out of its
      # own server. Loopback is already in the nixpkgs default, so only the
      # LAN is added here.
      services.fail2ban.ignoreIP = lib.mkIf cfg.enable [
        "192.168.1.0/24"
      ];

      # Repeat offenders get progressively longer bans instead of retrying
      # every 10 minutes forever. The default formula doubles bantime per
      # ban (10m, 20m, 40m, 1h20, ...); maxtime caps that at 72h so an
      # entry cannot grow unbounded. overalljails counts a host's bans
      # across every jail, so switching attack surface does not reset it.
      services.fail2ban.bantime-increment = lib.mkIf cfg.enable {
        enable = true;
        maxtime = "72h";
        overalljails = true;
        # Spread unban times by up to 15m so a botnet banned together does
        # not all come back in the same instant.
        rndtime = "15m";
      };
    };
}
