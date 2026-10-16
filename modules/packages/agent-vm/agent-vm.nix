{ inputs, ... }: {
  # Sandbox microVM for a coding agent, after
  # https://michael.stapelberg.ch/posts/2026-02-01-coding-agent-microvm-nix/
  #
  # - cloud-hypervisor guest, host /nix/store shared read-only via virtiofs,
  #   writable store overlay on a volume (nix-shell/direnv work inside)
  # - <stateDir>/workspace -> /workspace (repos cloned here on boot, visible on host)
  # - <stateDir>/home      -> /home/<user> (claude/gh logins persist across rebuilds)
  # - tap vm-<name>, host 192.168.83.1, guest 192.168.83.2, NAT out of dotfiles.network.interface
  #
  # Usage (host):
  #   sudo systemctl start microvm@<name>
  #   ssh <name>                       # /etc/hosts entry
  #   cd /workspace && claude --dangerously-skip-permissions
  # Dev servers are reachable from the host at http://<name>:<port> (3000-9999 open).
  flake.nixosModules.agent-vm = { config, lib, pkgs, ... }:
    let
      cfg = config.dotfiles.agentVm;
      user = config.dotfiles.user.name;
      tap = "vm-${cfg.name}";
      hostAddr = "192.168.83.1";
      guestAddr = "192.168.83.2";
      hostStateVersion = config.system.stateVersion;
    in {
      imports = [ inputs.microvm.nixosModules.host ];

      config = lib.mkMerge [
        { microvm.host.enable = lib.mkDefault cfg.enable; }

        (lib.mkIf cfg.enable {
          assertions = [{
            assertion = config.dotfiles.network.interface != null;
            message = "dotfiles.agentVm needs dotfiles.network.interface for NAT.";
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

          # Host networking for the tap: networkd only manages vm-*, NM keeps the rest.
          networking.networkmanager.unmanaged = [ "interface-name:vm-*" ];
          # networkd would pull in resolved (mkDefault); host DNS stays as before.
          services.resolved.enable = false;
          systemd.network = {
            enable = true;
            wait-online.enable = false;
            networks."30-microvm" = {
              matchConfig.Name = "vm-*";
              address = [ "${hostAddr}/24" ];
              networkConfig.ConfigureWithoutCarrier = true;
            };
          };
          networking.nat = {
            enable = true;
            internalInterfaces = [ tap ];
            externalInterface = config.dotfiles.network.interface;
          };
          networking.hosts.${guestAddr} = [ cfg.name ];

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
                  mac = "02:00:00:00:83:02";
                }];
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
                address = [ "${guestAddr}/24" ];
                gateway = [ hostAddr ];
                dns = [ "1.1.1.1" "1.0.0.1" ];
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
