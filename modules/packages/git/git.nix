{ ... }: {
  flake.nixosModules.git = { config, lib, pkgs, ... }: {
    home-manager.users.${config.dotfiles.user.name} = { lib, pkgs, osConfig, ... }:
      let onePassPath = "~/.1password/agent.sock";
      in {
        programs.ssh = {
          enable = true;
          enableDefaultConfig = false;
          matchBlocks = {
            "nucserver" = {
              forwardAgent = true;
              serverAliveInterval = 0;
              serverAliveCountMax = 3;
              compression = false;
              addKeysToAgent = "no";
              hashKnownHosts = false;
              controlMaster = "no";
              controlPersist = "no";
              extraOptions = lib.mkIf osConfig.dotfiles.programs._1password.sshAgent {
                IdentityAgent = onePassPath;
              };
            };
            "*" = {
              forwardAgent = false;
              serverAliveInterval = 0;
              serverAliveCountMax = 3;
              compression = false;
              addKeysToAgent = "no";
              hashKnownHosts = false;
              controlMaster = "no";
              controlPersist = "no";
              extraOptions = lib.mkIf osConfig.dotfiles.programs._1password.sshAgent {
                IdentityAgent = onePassPath;
              };
            };
          };
        };

        programs.git = {
          enable = true;
          signing.format = "openpgp";
          settings = {
            core.editor = {
              helix  = "hx";
              neovim = "nvim";
              zed    = "zed --wait";
            }.${osConfig.dotfiles.programs.defaultEditor};
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
