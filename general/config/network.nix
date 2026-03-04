{ pc, config, lib, ... }:
let
  cfg = config.dotfiles.network;
  hasStaticIP = cfg.staticIP != null && cfg.interface != null;
  addrParts = if hasStaticIP then lib.splitString "/" cfg.staticIP else [];
in
{
  networking = {
    hostName = if cfg.hostname != null then cfg.hostname else "nixos-${pc}";
    networkmanager.enable = true;
    networkmanager.dns = "none";
    nameservers = cfg.nameservers;
    useDHCP = lib.mkDefault (!hasStaticIP);
    defaultGateway = lib.mkIf hasStaticIP cfg.gateway;
    interfaces = lib.mkIf hasStaticIP {
      ${cfg.interface}.ipv4.addresses = [{
        address = lib.elemAt addrParts 0;
        prefixLength = lib.toInt (lib.elemAt addrParts 1);
      }];
    };
  };
  services.dnsmasq.resolveLocalQueries = false;
}
