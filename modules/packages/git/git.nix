{ ... }: {
  flake.nixosModules.git = { config, lib, pkgs, ... }: {
    home-manager.users.${config.dotfiles.user.name} = { lib, pkgs, osConfig, ... }:
      let onePassPath = "~/.1password/agent.sock";
      in {
        programs.ssh = {
          enable = true;
          enableDefaultConfig = false;
          settings = {
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
            };
            "*" = lib.hm.dag.entryAfter [ "nucserver" ] {
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
