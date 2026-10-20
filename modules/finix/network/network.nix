{ ... }: {
  # finix counterpart of modules/packages/network/network.nix.
  # NetworkManager does DHCP on every interface; DNS is the static
  # dotfiles.network.nameservers list (NixOS: networkmanager.dns = "none").
  flake.finixModules.network = { config, lib, modules, ... }:
    let
      cfg = config.dotfiles.network;
    in {
      imports = [ modules.networkmanager ];

      assertions = [
        {
          assertion = cfg.staticIP == null && !cfg.wakeOnLan;
          message = "finix network aspect: staticIP / wakeOnLan are not ported yet (only DHCP via NetworkManager).";
        }
      ];

      networking.hostName = if cfg.hostname != null then cfg.hostname else "finix";

      services.networkmanager = {
        enable = true;
        settings.main = {
          dns = "none";
          rc-manager = "unmanaged";
        };
      };

      environment.etc."resolv.conf".text =
        lib.concatMapStrings (ns: "nameserver ${ns}\n") cfg.nameservers;
    };
}
