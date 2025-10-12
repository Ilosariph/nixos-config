{ lib, pkgs, ... }: 
let
  username = "simon";
in {
  imports = [
    ./hypr/hyprland.nix
    ./hypr/hyprlock.nix
  ];

  programs.ssh = {
    enable = true;
	extraConfig = ''
      Host *
          IdentityAgent "~/.1password/agent.sock";
    '';
  };

  programs.git = {
    enable = true;
    extraConfig = {
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
        signingKey = "...";
      };
    };
  };

  programs.neovim.enable = true;
  xdg.configFile."nvim".source = ./nvim;

  home = {
    inherit username;
    homeDirectory = "/home/${username}";

    packages = with pkgs; [
      kdePackages.dolphin
      hyprshot
      discord
      grayjay
    ];

    sessionVariables = {
      XDG_THEME_MODE = "dark";
    };

    stateVersion = "23.11";
  };
}
