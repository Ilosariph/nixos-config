{ ... }: {
  flake.nixosModules.git = { config, lib, pkgs, ... }: {
    home-manager.users.${config.dotfiles.user.name} = { lib, pkgs, osConfig, ... }:
      let
        onePassPath = "~/.1password/agent.sock";
        priv = osConfig.dotfiles.private;
        # Host alias -> public keys ssh may offer there (IdentitiesOnly). Servers
        # default to the keys they authorize; private.nix ssh.pinnedKeys adds/overrides
        # (e.g. github.com). Hosts not listed stay unpinned (agent offers all keys).
        serverKeys = priv.ssh.authorizedKeys or [ ];
        pinnedKeys = {
          nucserver = serverKeys;
          evo = serverKeys;
          laptopserver = serverKeys;
          vps = priv.vps.authorizedKeys or [ ];
        } // lib.mapAttrs (_: lib.toList) (priv.ssh.pinnedKeys or { });
        pinned = lib.filterAttrs (_: ks: ks != [ ]) pinnedKeys;
        pubPath = host: i: ".ssh/pinned/${host}-${toString i}.pub";
        identityFiles = host: lib.imap0 (i: _: "~/${pubPath host i}") pinned.${host};
      in {
        home.file = lib.listToAttrs (lib.concatLists (lib.mapAttrsToList (host: ks:
          lib.imap0 (i: k: lib.nameValuePair (pubPath host i) { text = "${k}\n"; }) ks) pinned));

        programs.ssh = {
          enable = true;
          enableDefaultConfig = false;
          settings = lib.mapAttrs (host: _: {
            IdentityFile = identityFiles host;
            IdentitiesOnly = true;
          }) pinned // {
            "nucserver" = {
              ForwardAgent = true;
              ServerAliveInterval = 0;
              ServerAliveCountMax = 3;
              Compression = false;
              AddKeysToAgent = "no";
              HashKnownHosts = false;
              ControlMaster = "no";
              ControlPersist = "no";
              IdentityAgent = lib.mkIf osConfig.dotfiles.programs._1password.sshAgent onePassPath;
            } // lib.optionalAttrs (pinned ? nucserver) {
              IdentityFile = identityFiles "nucserver";
              IdentitiesOnly = true;
            };
            "*" = lib.hm.dag.entryAfter ([ "nucserver" ] ++ lib.attrNames pinned) {
              ForwardAgent = false;
              ServerAliveInterval = 0;
              ServerAliveCountMax = 3;
              Compression = false;
              AddKeysToAgent = "no";
              HashKnownHosts = false;
              ControlMaster = "no";
              ControlPersist = "no";
              IdentityAgent = lib.mkIf osConfig.dotfiles.programs._1password.sshAgent onePassPath;
            };
          };
        };

        programs.git = {
          enable = true;
          signing.format = "openpgp";
          settings = {
            gpg = {
              format = "ssh";
            };
            "gpg \"ssh\"" = {
              program = "${lib.getExe' pkgs._1password-gui "op-ssh-sign"}";
            };
            commit = {
              gpgsign = true;
            };
            user = {
              name = "Ilosariph";
              email = "71074737+Ilosariph@users.noreply.github.com";
              signingKey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIDk/LW0RX25BW64tJrsU7VFMqlSPR6zto9lAYghBLvie";
            };
            init = {
              defaultBranch = "main";
            };
          };
        };
      };
  };
}
