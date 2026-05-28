{ ... }: {
  flake.nixosModules.evil-ap = { config, lib, pkgs, ... }:
    let
      cfg = config.dotfiles.programs.evilAp;
      apIp = "10.6.6.1";
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

      # DHCP + DNS — redirect every domain to us, no upstream leakage
      services.dnsmasq = {
        enable = true;
        settings = {
          interface = cfg.interface;
          bind-interfaces = true;
          # hand out addresses in the AP subnet
          "dhcp-range" = [ "10.6.6.50,10.6.6.200,1h" ];
          # wildcard: every DNS query returns our IP
          address = "/#/${apIp}";
          # don't read resolv.conf or forward anything upstream
          no-resolv = true;
        };
      };

      # Troll page served by nginx
      services.nginx = {
        enable = true;
        # rate-limit AP clients so a bored connected person can't hammer us
        appendHttpConfig = ''
          limit_req_zone $binary_remote_addr zone=evil_ap:2m rate=20r/s;
        '';
        virtualHosts.captive = {
          default = true;
          listen = [{ addr = apIp; port = 80; ssl = false; }];
          root = pkgs.writeTextDir "index.html" cfg.portalHtml;
          locations."/" = {
            index = "index.html";
            extraConfig = ''
              try_files $uri $uri/ /index.html;
              limit_req zone=evil_ap burst=40 nodelay;
            '';
          };
          # OS captive-portal detection endpoints — trigger the popup on every platform
          locations."= /generate_204"      = { return = "302 http://${apIp}/"; };  # Android
          locations."= /hotspot-detect.html" = { return = "302 http://${apIp}/"; };  # Apple
          locations."= /connecttest.txt"   = { return = "302 http://${apIp}/"; };  # Windows
          locations."= /ncsi.txt"          = { return = "302 http://${apIp}/"; };  # Windows
          locations."= /success.txt"       = { return = "302 http://${apIp}/"; };  # Firefox
        };
      };

      networking.nftables.enable = true;
      networking.nftables.tables.evil-ap = {
        family = "ip";
        content = ''
          # Redirect all HTTP/HTTPS from AP clients to our nginx regardless of
          # where they think they're going (catches captive portal checks too).
          chain prerouting {
            type nat hook prerouting priority dstnat;
            iifname "${cfg.interface}" tcp dport { 80, 443 } dnat to ${apIp}:80
          }

          # Drop all forwarded traffic to and from the AP interface.
          # This is the critical safety rule: AP clients cannot reach your LAN,
          # other machines on the LAN cannot reach AP clients, and no actual
          # internet is accidentally provided even with ip_forward enabled.
          chain forward {
            type filter hook forward priority filter;
            iifname "${cfg.interface}" drop
            oifname "${cfg.interface}" drop
          }

          # Block SSH on ALL interfaces while the AP is active.
          # Running at priority filter - 10 means this executes before the NixOS
          # firewall (priority filter = 0), so the DROP is terminal even if
          # services.openssh has added an ACCEPT rule in nixos-fw.
          # You should not be SSH-reachable while broadcasting a bait network
          # in public.
          chain block-ssh {
            type filter hook input priority filter - 10;
            tcp dport 22 drop
          }
        '';
      };

      # ip_forward is needed for the DNAT redirect to work (kernel requires it
      # even for traffic destined for the local machine after rewrite).
      boot.kernel.sysctl."net.ipv4.ip_forward" = 1;

      # Allow only the services AP clients actually need to reach on this host.
      # Everything else hitting the input chain is dropped by the NixOS firewall.
      networking.firewall.interfaces.${cfg.interface} = {
        allowedTCPPorts = [ 80 53 ];
        allowedUDPPorts = [ 53 67 ];  # DNS + DHCP
      };
    };
}
