{ ... }: {
  flake.nixosModules.helix = { config, lib, pkgs, ... }: {
    home-manager.users.${config.dotfiles.user.name} = { lib, osConfig, ... }:
      lib.mkIf osConfig.dotfiles.programs.helix.enable {
        programs.helix = {
          enable = true;
          extraPackages = with pkgs; [
            # Python
            pyright
            ruff
            # Lua
            lua-language-server
            stylua
            # Nix
            nil
            nixfmt-rfc-style
          ];

          settings = {
            theme = "tokyonight_night";

            editor = {
              line-number = "relative";
              mouse = true;
              cursorline = true;
              scrolloff = 5;
              auto-format = true;
              idle-timeout = 250;
              completion-timeout = 250;
              color-modes = true;
              bufferline = "multiple";

              cursor-shape = {
                insert = "bar";
                normal = "block";
                select = "underline";
              };

              indent-guides = {
                render = true;
                character = "│";
              };

              lsp = {
                display-inlay-hints = true;
                display-messages = true;
              };

              gutters.layout = [ "diagnostics" "spacer" "line-numbers" "spacer" "diff" ];

              statusline = {
                left = [ "mode" "spinner" "file-name" "file-modification-indicator" ];
                center = [ ];
                right = [ "diagnostics" "selections" "register" "position" "file-encoding" "file-type" ];
                separator = "│";
                mode = {
                  normal = "NORMAL";
                  insert = "INSERT";
                  select = "SELECT";
                };
              };

              whitespace = {
                render = {
                  tab = "all";
                  space = "none";
                  newline = "none";
                };
                characters = {
                  tab = "→";
                  tabpad = " ";
                  space = "·";
                  nbsp = "␣";
                };
              };

              search.smart-case = true;

              # Show hidden files in picker (like fd/telescope in nvim)
              file-picker.hidden = false;
            };

            keys = {
              normal = {
                # Window navigation (mirrors C-h/j/k/l from vim-tmux-navigator)
                "C-h" = "jump_view_left";
                "C-j" = "jump_view_down";
                "C-k" = "jump_view_up";
                "C-l" = "jump_view_right";

                # File picker toggle (mirrors \ → Neo-tree in nvim)
                "\\" = "file_picker";

                # Git hunk navigation: add ]c/[c aliases alongside helix defaults ]g/[g
                "]" = { c = "goto_next_change"; };
                "[" = { c = "goto_prev_change"; };

                space = {
                  # Manual format (auto-format on save handles the common case)
                  "=" = ":format";
                  # Diagnostics list (mirrors <leader>q in nvim)
                  "q" = "diagnostics_picker";
                  # Defaults already cover:
                  #   space r  = rename_symbol      (<leader>rn / IdeaVim <leader>rn)
                  #   space a  = code_action         (<leader>rf / IdeaVim <leader>rf)
                  #   space s  = symbol_picker       (<leader>sm / IdeaVim <leader>sm)
                  #   space S  = workspace_symbol    (<leader>sp / IdeaVim <leader>sp)
                  #   space /  = global_search       (<leader>sg / IdeaVim <leader>sg)
                  #   space f  = file_picker         (<leader>sf)
                };
              };
            };
          };

          languages = {
            language-server = {
              pyright = {
                command = "pyright-langserver";
                args = [ "--stdio" ];
                config.python.analysis.typeCheckingMode = "basic";
              };

              ruff = {
                command = "ruff";
                args = [ "server" ];
              };

              lua-language-server.command = "lua-language-server";

              nil.command = "nil";
            };

            language = [
              {
                name = "python";
                language-servers = [ "pyright" "ruff" ];
                auto-format = true;
                formatter = {
                  command = "ruff";
                  args = [ "format" "--stdin-filename" "file.py" "-" ];
                };
              }
              {
                name = "lua";
                language-servers = [ "lua-language-server" ];
                auto-format = true;
                formatter = {
                  command = "stylua";
                  args = [ "-" ];
                };
              }
              {
                name = "nix";
                language-servers = [ "nil" ];
                auto-format = true;
                formatter.command = "nixfmt";
              }
            ];
          };
        };

        # Desktop entry: launches helix inside a new kitty window (helix is a TUI)
        xdg.desktopEntries.helix-kitty = {
          name = "Helix";
          genericName = "Text Editor";
          comment = "A post-modern modal text editor";
          exec = "kitty hx %F";
          terminal = false;
          categories = [ "Utility" "TextEditor" ];
          icon = "helix";
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
