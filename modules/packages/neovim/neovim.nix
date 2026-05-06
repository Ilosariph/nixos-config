{ ... }: {
  flake.nixosModules.neovim = { config, lib, ... }: {
    home-manager.users.${config.dotfiles.user.name} = { lib, osConfig, ... }:
      lib.mkIf osConfig.dotfiles.programs.nvim.enable {
        programs.neovim = {
          enable = true;
          withRuby = false;
          withPython3 = false;
        };
        xdg.configFile."nvim" = {
          source = ./nvim;
        };
        xdg.desktopEntries.nvim-kitty = {
          name = "Neovim";
          genericName = "Text Editor";
          comment = "Hyperextensible Vim-based text editor";
          exec = "kitty nvim %F";
          terminal = false;
          categories = [ "Utility" "TextEditor" ];
          icon = "nvim";
          startupNotify = false;
          mimeType = [
            "text/plain"
            "text/markdown"
            "text/x-markdown"
            "text/css"
            "text/javascript"
            "text/x-shellscript"
            "text/x-python"
            "text/x-script.python"
            "text/x-nix"
            "text/x-toml"
            "text/x-yaml"
            "text/x-lua"
            "text/x-c"
            "text/x-csrc"
            "text/x-c++src"
            "text/x-java"
            "text/x-makefile"
            "text/x-rust"
            "application/json"
            "application/toml"
            "application/xml"
            "application/x-yaml"
            "text/xml"
          ];
        };
      };
  };
}
