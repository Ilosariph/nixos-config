{ ... }: {
  # home-manager programs.git + programs.ssh → ~/.config/git/config, ~/.ssh/config
  flake.finixModules.git = { config, lib, pkgs, ... }:
    let
      onePassPath = "~/.1password/agent.sock";
      useAgent = config.dotfiles.programs._1password.sshAgent;

      hostBlock = host: forwardAgent: ''
        Host ${host}
          ForwardAgent ${if forwardAgent then "yes" else "no"}
          ServerAliveInterval 0
          ServerAliveCountMax 3
          Compression no
          AddKeysToAgent no
          HashKnownHosts no
          ControlMaster no
          ControlPersist no
        ${lib.optionalString useAgent "  IdentityAgent ${onePassPath}"}
      '';
    in {
      environment.systemPackages = [ pkgs.git pkgs.openssh ];

      hjem.users.${config.dotfiles.user.name} = {
        files.".ssh/config".text = hostBlock "nucserver" true + "\n" + hostBlock "*" false;

        xdg.config.files."git/config".text = lib.generators.toGitINI {
          gpg.format = "ssh";
          "gpg \"ssh\"".program = "${lib.getExe' pkgs._1password-gui "op-ssh-sign"}";
          commit.gpgsign = true;
          user = {
            name = "Ilosariph";
            email = "71074737+Ilosariph@users.noreply.github.com";
            signingKey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIDk/LW0RX25BW64tJrsU7VFMqlSPR6zto9lAYghBLvie";
          };
          init.defaultBranch = "main";
        };
      };
    };
}
