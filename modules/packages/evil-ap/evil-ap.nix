{ ... }: {
  flake.nixosModules.evil-ap = { config, lib, pkgs, ... }:
    let
      cfg = config.dotfiles.programs.evilAp;
      apIp = "10.6.6.1";
      apSubnet = "10.6.6.0/24";
    in
    lib.mkIf cfg.enable {
      # Create the WiFi access point
      services.hostapd = {
        enable = true;
        radios.${cfg.interface} = {
          networks.${cfg.interface} = {
            ssid = cfg.ssid;
            authentication.mode = "none";
          };
          band = "2g";
          channel = cfg.channel;
        };
      };

      # Assign static IP to the AP interface
      networking.interfaces.${cfg.interface}.ipv4.addresses = [{
        address = apIp;
        prefixLength = 24;
      }];

      # DHCP + DNS — redirect every domain to us
      services.dnsmasq = {
        enable = true;
        settings = {
          interface = cfg.interface;
          bind-interfaces = true;
          dhcp-range = [ "${apIp},10.6.6.50,10.6.6.200,24h" ];
          # redirect all DNS queries to our IP regardless of what they asked for
          address = "/#/${apIp}";
          no-resolv = true;
          server = [];
        };
      };

      # Troll page served by nginx
      services.nginx = {
        enable = true;
        virtualHosts.captive = {
          default = true;
          listen = [{ addr = apIp; port = 80; ssl = false; }];
          root = pkgs.writeTextDir "index.html" cfg.portalHtml;
          locations."/" = {
            index = "index.html";
            extraConfig = "try_files $uri $uri/ /index.html;";
          };
          # Captive portal detection endpoints — redirect everything here
          locations."= /generate_204" = { return = "302 http://${apIp}/"; };
          locations."= /hotspot-detect.html" = { return = "302 http://${apIp}/"; };
          locations."= /connecttest.txt" = { return = "302 http://${apIp}/"; };
          locations."= /ncsi.txt" = { return = "302 http://${apIp}/"; };
          locations."= /success.txt" = { return = "302 http://${apIp}/"; };
        };
      };

      # NAT redirect — catches HTTP/HTTPS on any dest, sends to nginx
      networking.nftables.enable = true;
      networking.nftables.tables.evil-ap = {
        family = "ip";
        content = ''
          chain prerouting {
            type nat hook prerouting priority dstnat;
            iifname "${cfg.interface}" tcp dport { 80, 443 } dnat to ${apIp}:80
          }
          chain postrouting {
            type nat hook postrouting priority srcnat;
            oifname "${cfg.interface}" masquerade
          }
        '';
      };

      boot.kernel.sysctl."net.ipv4.ip_forward" = 1;

      networking.firewall.interfaces.${cfg.interface} = {
        allowedTCPPorts = [ 80 443 53 ];
        allowedUDPPorts = [ 53 67 68 ];
      };
    };
}
