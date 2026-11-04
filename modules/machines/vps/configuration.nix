{ config, lib, pkgs, ... }:
let
  vps = config.dotfiles.private.vps;
  prefixLength = vps.prefixLength or 24;
  # Network address of vps.ipv4/prefixLength.
  subnet =
    let
      ip = lib.foldl (acc: o: acc * 256 + lib.toInt o) 0 (lib.splitString "." vps.ipv4);
      block = lib.foldl (acc: _: acc * 2) 1 (lib.range 1 (32 - prefixLength));
      net = ip / block * block;
    in
    lib.concatMapStringsSep "." (s: toString (lib.mod (net / s) 256)) [ 16777216 65536 256 1 ];
in
{
  imports = [
    ./backup.nix
    ./crowdsec.nix
    ./pangolin.nix
  ];

  # Static config only (network-addresses-eth0); NetworkManager would try DHCP
  # on eth0, which the VPS network doesn't serve.
  networking.networkmanager.enable = lib.mkForce false;

  # Single NIC; keep the eth0 name netplan used.
  networking.usePredictableInterfaceNames = false;
  networking.interfaces.eth0 = {
    ipv6.addresses = [{ address = vps.ipv6; prefixLength = 64; }];
    # The provider doesn't switch the subnet between guests: route it via the gateway
    # instead of on-link (Ubuntu did this with an @reboot cron entry).
    ipv4.routes = [{
      address = subnet;
      inherit prefixLength;
      via = vps.gateway;
      options.metric = "10";
    }];
  };
  networking.defaultGateway6 = { address = "fe80::1"; interface = "eth0"; };

  # Docker-published ports (gerbil) bypass this anyway via the DOCKER chain.
  networking.firewall = {
    allowedTCPPorts = [ 22 80 443 ];
    allowedUDPPorts = [ 51820 21820 ];
  };

  services.openssh.settings = {
    PermitRootLogin = "no";
    PasswordAuthentication = false;
    KbdInteractiveAuthentication = false;
  };

  boot.loader.grub.useOSProber = lib.mkForce false;
  # dotfiles.bootloader sets "max", which GRUB rejects here (console errors).
  boot.loader.grub.gfxmodeEfi = lib.mkForce "auto";
  # disko adds the disk with the EF02 partition to grub.devices itself; drop
  # dotfiles.bootloader.grubDevice so it isn't listed twice.
  boot.loader.grub.device = lib.mkForce "";

  # Gerbil (Pangolin) runs WireGuard in-kernel; its modprobe can't see NixOS's
  # module tree from inside the container, so load it on the host.
  boot.kernelModules = [ "wireguard" ];

  boot.kernel.sysctl."vm.max_map_count" = 1048576;

  zramSwap.enable = true;

  # Stacks live in /docker/{compose,data,important,www}, managed by hand.
  systemd.tmpfiles.rules = [ "d /docker 0755 root root -" ];
  # Like Ubuntu: dockerd stops the containers (clean DB shutdown) when it stops.
  # With live-restore they outlive it and systemd-shutdown kills them after 90s.
  virtualisation.docker.liveRestore = false;
  users.users.${config.dotfiles.user.name} = {
    extraGroups = [ "docker" ];
    # Root login is off, so sudo (and the VNC console) need a password
    # from the start. Value: `mkpasswd -m yescrypt`.
    hashedPasswordFile = config.sops.secrets.simon-password-hash.path;
  };
  sops.secrets.simon-password-hash.neededForUsers = true;

  # Registry auth for dockerregistry pulls.
  sops.secrets.docker-config = {
    path = "/root/.docker/config.json";
    mode = "0400";
  };

  environment.systemPackages = with pkgs; [
    jq
    sqlite
  ];
}
