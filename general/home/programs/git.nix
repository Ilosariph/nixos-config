{ lib, pkgs, ... }:
let
  onePassPath = "~/.1password/agent.sock";
in {
  programs.ssh = {
	enable = true;
	enableDefaultConfig = false;
	matchBlocks."*" = {
	  forwardAgent = false;
	  serverAliveInterval = 0;
	  serverAliveCountMax = 3;
	  compression = false;
	  addKeysToAgent = "no";
	  hashKnownHosts = false;
	  controlMaster = "no";
	  controlPersist = "no";
	  extraOptions = {
		"Host" = ''
*
    IdentityAgent ${onePassPath}
		'';
	  };
	};
  };

  programs.git = {
	enable = true;
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
    };
  };

}
