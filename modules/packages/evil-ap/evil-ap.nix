{ ... }: {
  flake.nixosModules.evil-ap = { config, lib, pkgs, ... }:
    let
      cfg = config.dotfiles.programs.evilAp;
      apIp = "10.6.6.1";
      portalContent = if cfg.portalHtml != null then cfg.portalHtml else builtins.readFile ./portal.html;

      nmcli     = "${pkgs.networkmanager}/bin/nmcli";
      ip        = "${pkgs.iproute2}/bin/ip";
      systemctl = "${pkgs.systemd}/bin/systemctl";
      awk       = "${pkgs.gawk}/bin/awk";

      # Shell function embedded in scripts that need to check WiFi state
      wifiUpFn = ''
        wifi_client_up() {
          ${nmcli} -t -f DEVICE,TYPE,STATE device status 2>/dev/null \
            | ${awk} -F: -v ap="${cfg.interface}" \
                '$1 != ap && $2 == "wifi" && $3 == "connected" { f=1 } END { exit !f }'
        }
      '';

      # Release interface from NM, assign AP IP, start sub-services
      startScript = pkgs.writeShellScript "evil-ap-start" ''
        set -euo pipefail
        ${nmcli} device set "${cfg.interface}" managed no
        ${ip} addr flush dev "${cfg.interface}"
        ${ip} link set "${cfg.interface}" up
        ${systemctl} start hostapd.service
        ${ip} addr add ${apIp}/24 dev "${cfg.interface}" 2>/dev/null || true
        ${systemctl} start dnsmasq.service
      '';

      # Stop sub-services, flush IP, return interface to NM
      stopScript = pkgs.writeShellScript "evil-ap-stop" ''
        set -euo pipefail
        ${systemctl} stop hostapd.service dnsmasq.service || true
        ${ip} addr flush dev "${cfg.interface}" || true
        ${nmcli} device set "${cfg.interface}" managed yes
      '';

      # Boot-time check: start AP if NM hasn't connected to anything after settling
      initScript = pkgs.writeShellScript "evil-ap-init" ''
        ${wifiUpFn}
        sleep 15
        if [[ ! -f /run/evil-ap-paused ]] && ! wifi_client_up; then
          ${systemctl} start evil-ap.service
        fi
      '';

      # NM dispatcher: start/stop the AP as WiFi client connects/disconnects
      dispatcherScript = pkgs.writeShellScript "evil-ap-dispatcher" ''
        IFACE="$1"
        ACTION="$2"
        [[ "$IFACE" == "${cfg.interface}" ]] && exit 0
        ${wifiUpFn}
        case "$ACTION" in
          up|dhcp4-change|connectivity-change)
            if wifi_client_up && ${systemctl} is-active --quiet evil-ap.service; then
              ${systemctl} stop evil-ap.service
            fi
            ;;
          down|pre-down)
            sleep 3  # let NM settle before concluding we're offline
            if [[ ! -f /run/evil-ap-paused ]] \
                && ! wifi_client_up \
                && ! ${systemctl} is-active --quiet evil-ap.service; then
              ${systemctl} start evil-ap.service
            fi
            ;;
        esac
      '';

      # User-facing commands (need root — NOPASSWD sudo rules added below)
      pauseCmd = pkgs.writeShellScriptBin "evil-ap-pause" ''
        touch /run/evil-ap-paused
        ${systemctl} stop evil-ap.service
        echo "evil-ap paused until reboot or 'sudo evil-ap-resume'"
      '';

      resumeCmd = pkgs.writeShellScriptBin "evil-ap-resume" ''
        ${wifiUpFn}
        rm -f /run/evil-ap-paused
        if wifi_client_up; then
          echo "WiFi is connected — evil-ap will start automatically when it drops"
        else
          ${systemctl} start evil-ap.service
          echo "evil-ap started"
        fi
      '';

    in
    lib.mkIf cfg.enable {
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

      services.dnsmasq = {
        enable = true;
        settings = {
          interface = cfg.interface;
          bind-interfaces = true;
          "dhcp-range" = [ "10.6.6.50,10.6.6.200,1h" ];
          address = "/#/${apIp}";
          no-resolv = true;
        };
      };

      # IP is managed at runtime by the start/stop scripts — a static assignment
      # here would conflict with NM when the same interface is used as a WiFi client.
      # Don't auto-start either service; evil-ap.service drives them.
      systemd.services.hostapd.wantedBy = lib.mkForce [];
      systemd.services.dnsmasq.wantedBy = lib.mkForce [];

      services.nginx = {
        enable = true;
        appendHttpConfig = ''
          limit_req_zone $binary_remote_addr zone=evil_ap:2m rate=20r/s;
        '';
        virtualHosts.captive = {
          default = true;
          listen = [{ addr = apIp; port = 80; ssl = false; }];
          root = pkgs.writeTextDir "index.html" portalContent;
          locations."/" = {
            index = "index.html";
            extraConfig = ''
              try_files $uri $uri/ /index.html;
              limit_req zone=evil_ap burst=40 nodelay;
            '';
          };
          locations."= /generate_204"        = { return = "302 http://${apIp}/"; };
          locations."= /hotspot-detect.html" = { return = "302 http://${apIp}/"; };
          locations."= /connecttest.txt"     = { return = "302 http://${apIp}/"; };
          locations."= /ncsi.txt"            = { return = "302 http://${apIp}/"; };
          locations."= /success.txt"         = { return = "302 http://${apIp}/"; };
        };
      };

      networking.nftables.enable = true;
      networking.nftables.tables.evil-ap = {
        family = "ip";
        content = ''
          chain prerouting {
            type nat hook prerouting priority dstnat;
            iifname "${cfg.interface}" tcp dport { 80, 443 } dnat to ${apIp}:80
          }
          chain forward {
            type filter hook forward priority filter;
            iifname "${cfg.interface}" drop
            oifname "${cfg.interface}" drop
          }
          chain block-ssh {
            type filter hook input priority filter - 10;
            tcp dport 22 drop
          }
        '';
      };

      boot.kernel.sysctl."net.ipv4.ip_forward" = 1;

      networking.firewall.interfaces.${cfg.interface} = {
        allowedTCPPorts = [ 80 53 ];
        allowedUDPPorts = [ 53 67 ];
      };

      # Orchestrator: manages IP assignment and sub-service lifecycle
      systemd.services.evil-ap = {
        description = "evil captive portal AP";
        after = [ "NetworkManager.service" "network-pre.target" ];
        requires = [ "NetworkManager.service" ];
        serviceConfig = {
          Type = "oneshot";
          RemainAfterExit = true;
          ExecStart = startScript;
          ExecStop = stopScript;
        };
      };

      # On boot: start the AP if NM hasn't connected to WiFi after ~15s
      systemd.services.evil-ap-init = {
        description = "evil-ap: initial WiFi state check";
        after = [ "NetworkManager.service" ];
        wants = [ "NetworkManager.service" ];
        wantedBy = [ "multi-user.target" ];
        serviceConfig = {
          Type = "oneshot";
          ExecStart = initScript;
        };
      };

      # React to WiFi connect/disconnect events via NetworkManager
      networking.networkmanager.dispatcherScripts = [{
        source = dispatcherScript;
        type = "basic";
      }];

      environment.systemPackages = [ pauseCmd resumeCmd ];

      # Allow the primary user to pause/resume without a password prompt
      security.sudo.extraRules = [{
        users = [ config.dotfiles.user.name ];
        commands = [
          { command = "${pauseCmd}/bin/evil-ap-pause";  options = [ "NOPASSWD" ]; }
          { command = "${resumeCmd}/bin/evil-ap-resume"; options = [ "NOPASSWD" ]; }
        ];
      }];
    };
}
