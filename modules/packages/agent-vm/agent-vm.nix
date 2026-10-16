{ inputs, ... }: {
  # Sandbox microVM for a coding agent, after
  # https://michael.stapelberg.ch/posts/2026-02-01-coding-agent-microvm-nix/
  #
  # - cloud-hypervisor guest, host /nix/store shared read-only via virtiofs,
  #   writable store overlay on a volume (nix-shell/direnv work inside)
  # - <stateDir>/workspace -> /workspace (repos cloned here on boot, visible on host)
  # - <stateDir>/home      -> /home/<user> (claude/gh logins persist across rebuilds)
  # - tap vm-<name> bridged (br0) onto the LAN, static dotfiles.agentVm.address
  #
  # Usage (host):
  #   sudo systemctl start microvm@<name>
  #   ssh <name>                       # /etc/hosts entry
  #   cd /workspace && claude --dangerously-skip-permissions
  # Dev servers reachable at http://<name>:<port> (3000-9999 open, LAN-wide).
  flake.nixosModules.agent-vm = { config, lib, pkgs, ... }:
    let
      cfg = config.dotfiles.agentVm;
      user = config.dotfiles.user.name;
      tap = "vm-${cfg.name}";
      lanIf = config.dotfiles.network.interface;
      guestIp = lib.head (lib.splitString "/" cfg.address);
      hostStateVersion = config.system.stateVersion;
      hostNameservers = config.dotfiles.network.nameservers;
    in {
      imports = [ inputs.microvm.nixosModules.host ];

      config = lib.mkMerge [
        { microvm.host.enable = lib.mkDefault cfg.enable; }

        (lib.mkIf cfg.enable {
          assertions = [{
            assertion = config.dotfiles.network.interface != null;
            message = "dotfiles.agentVm needs dotfiles.network.interface (NIC bridged into ${cfg.bridge}).";
          }];

          # Host-side share dirs. Guest user has uid 1000 → must match host user's uid
          # (virtiofs passes uids through).
          systemd.tmpfiles.rules = [
            "d /home/${user}/microvm 0755 ${user} users -"
            "d ${cfg.stateDir} 0755 ${user} users -"
            "d ${cfg.stateDir}/workspace 0755 ${user} users -"
            "d ${cfg.stateDir}/home 0700 ${user} users -"
            "d ${cfg.stateDir}/ssh-host-keys 0700 root root -"
          ];

          # Host networking: NM bridges the LAN NIC into br0 (host DHCPs on br0), the
          # VM's tap is enslaved to br0 by tap-up below → VM sits on the LAN itself.
          networking.networkmanager.unmanaged = [ "interface-name:vm-*" ];
          networking.networkmanager.ensureProfiles.profiles = {
            ${cfg.bridge} = {
              connection = {
                id = cfg.bridge;
                type = "bridge";
                interface-name = cfg.bridge;
                autoconnect = true;
              };
              bridge.stp = false;
              ipv4.method = "auto";
              ipv6.method = "auto";
            };
            "${cfg.bridge}-port-${lanIf}" = {
              connection = {
                id = "${cfg.bridge}-port-${lanIf}";
                type = "ethernet";
                interface-name = lanIf;
                master = cfg.bridge;
                slave-type = "bridge";
                autoconnect = true;
                # Beat NM's auto "Wired connection 1" on the same NIC.
                autoconnect-priority = 100;
              };
            };
          };
          networking.hosts.${guestIp} = [ cfg.name ];

          microvm.vms.${cfg.name} = {
            inherit (cfg) autostart;
            config = { lib, pkgs, ... }: {
              system.stateVersion = hostStateVersion;
              networking.hostName = cfg.name;

              microvm = {
                hypervisor = "cloud-hypervisor";
                inherit (cfg) vcpu mem;
                vsock.cid = 3; # systemd-notify readiness for microvm@ unit
                interfaces = [{
                  type = "tap";
                  id = tap;
                  mac = "02:00:00:00:01:04";
                }];
                binScripts.tap-up = lib.mkAfter ''
                  ${lib.getExe' pkgs.iproute2 "ip"} link set '${tap}' master '${cfg.bridge}'
                '';
                shares = [
                  {
                    proto = "virtiofs";
                    tag = "ro-store";
                    source = "/nix/store";
                    mountPoint = "/nix/.ro-store";
                  }
                  {
                    proto = "virtiofs";
                    tag = "workspace";
                    source = "${cfg.stateDir}/workspace";
                    mountPoint = "/workspace";
                  }
                  {
                    proto = "virtiofs";
                    tag = "home";
                    source = "${cfg.stateDir}/home";
                    mountPoint = "/home/${user}";
                  }
                  {
                    proto = "virtiofs";
                    tag = "ssh-host-keys";
                    source = "${cfg.stateDir}/ssh-host-keys";
                    mountPoint = "/etc/ssh/host-keys";
                  }
                ];
                writableStoreOverlay = "/nix/.rw-store";
                volumes = [{
                  image = "nix-store-overlay.img";
                  mountPoint = "/nix/.rw-store";
                  size = 20480;
                }];
              };

              networking.useDHCP = false;
              networking.useNetworkd = true;
              systemd.network.networks."20-lan" = {
                matchConfig.Type = "ether";
                address = [ cfg.address ];
                gateway = [ cfg.gateway ];
                dns = hostNameservers;
              };
              networking.firewall = {
                allowedTCPPorts = [ 22 ];
                allowedTCPPortRanges = [{ from = 3000; to = 9999; }];
              };

              services.openssh = {
                enable = true;
                settings.PasswordAuthentication = false;
                hostKeys = [{
                  path = "/etc/ssh/host-keys/ssh_host_ed25519_key";
                  type = "ed25519";
                }];
              };

              users.users.${user} = {
                isNormalUser = true;
                uid = 1000;
                extraGroups = [ "wheel" ];
                openssh.authorizedKeys.keys = cfg.authorizedKeys;
              };
              # Throwaway sandbox: agent may sudo freely (nix, package installs).
              security.sudo.wheelNeedsPassword = false;

              nix.settings = {
                experimental-features = [ "nix-command" "flakes" ];
                trusted-users = [ user ];
              };

              programs.git.enable = true;
              programs.direnv.enable = true;
              environment.systemPackages = with pkgs; [
                claude-code
                gh
                nodejs
                python3
                ripgrep
                fd
                jq
                tmux
                neovim
                curl
                ffmpeg
              ];

              # Clone missing repos into the shared workspace (never touches existing ones).
              systemd.services.clone-repos = {
                description = "Clone game repos into /workspace";
                wantedBy = [ "multi-user.target" ];
                wants = [ "network-online.target" ];
                after = [ "network-online.target" ];
                unitConfig.RequiresMountsFor = [ "/workspace" ];
                path = [ pkgs.git ];
                serviceConfig = {
                  Type = "oneshot";
                  User = user;
                  RemainAfterExit = true;
                };
                script = lib.concatMapStrings (repo: ''
                  if [ ! -d /workspace/${repo} ]; then
                    git clone https://github.com/${cfg.githubOwner}/${repo}.git /workspace/${repo} \
                      || echo "clone of ${repo} failed"
                  fi
                '') cfg.repos;
              };
            };
          };
        })
      ];
    };
}
