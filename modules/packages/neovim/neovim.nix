{ ... }: {
  flake.nixosModules.neovim = { config, lib, ... }: {
    home-manager.users.${config.dotfiles.user.name} = { lib, osConfig, ... }:
      lib.mkIf osConfig.dotfiles.programs.nvim.enable
        (let
          wm = osConfig.dotfiles.windowManager.settings;
          # WM option values ("H","N","comma"…) → nvim key names
          toKey = k: { H="h"; L="l"; K="k"; J="j"; N="n"; I="i"; U="u"; comma=","; }.${k};
          # Shift variant: uppercase letter = Alt+Shift+letter; comma → <A-lt> (Alt+<)
          toShift = k: { H="H"; L="L"; K="K"; J="J"; N="N"; I="I"; U="U"; comma="lt"; }.${k};
          lk = toKey  wm.left;  rk = toKey  wm.right;  uk = toKey  wm.up;  dk = toKey  wm.down;
          ls = toShift wm.left; rs = toShift wm.right; us = toShift wm.up; ds = toShift wm.down;
        in {
          programs.neovim = {
            enable = true;
            withRuby = false;
            withPython3 = false;
          };
          # recursive = true links each file individually so we can inject extra files
          xdg.configFile."nvim" = { source = ./nvim; recursive = true; };
          # after/plugin/ is auto-sourced by neovim after plugins load
          xdg.configFile."nvim/after/plugin/keybindings.lua".text = ''
            -- Alt+Left/Right: tab navigation
            vim.keymap.set('n', '<A-Right>', ':tabnext<CR>',     { silent = true })
            vim.keymap.set('n', '<A-Left>',  ':tabprevious<CR>', { silent = true })
            -- Alt+WM-move: split navigation
            vim.keymap.set('n', '<A-${lk}>', '<C-w>h', { silent = true })
            vim.keymap.set('n', '<A-${rk}>', '<C-w>l', { silent = true })
            vim.keymap.set('n', '<A-${uk}>', '<C-w>k', { silent = true })
            vim.keymap.set('n', '<A-${dk}>', '<C-w>j', { silent = true })
            -- Alt+Shift+WM-move: move current split to that edge
            vim.keymap.set('n', '<A-${ls}>', '<C-w>H', { silent = true })
            vim.keymap.set('n', '<A-${rs}>', '<C-w>L', { silent = true })
            vim.keymap.set('n', '<A-${us}>', '<C-w>K', { silent = true })
            vim.keymap.set('n', '<A-${ds}>', '<C-w>J', { silent = true })
          '';
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
        });
  };
}
