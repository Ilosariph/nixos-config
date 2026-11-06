{ inputs, ... }: {
  # Neovim via nixvim. Port of the former kickstart.nvim lua config (lazy.nvim +
  # mason); plugins, LSP servers and formatters now come from nixpkgs.
  flake.nixosModules.neovim = { config, lib, ... }: {
    home-manager.sharedModules = [ inputs.nixvim.homeModules.nixvim ];

    home-manager.users.${config.dotfiles.user.name} = { lib, pkgs, osConfig, ... }:
      lib.mkIf osConfig.dotfiles.programs.neovim.enable {
        programs.nixvim = {
          enable = true;
          # Reuse the system pkgs (allowUnfree, overlays) instead of a second instance.
          nixpkgs.useGlobalPackages = true;
          withRuby = false;
          withPython3 = false;

          globals = {
            mapleader = " ";
            maplocalleader = " ";
            have_nerd_font = true;
          };

          opts = {
            number = true;
            relativenumber = true;
            mouse = "a";
            showmode = false;
            breakindent = true;
            undofile = true;
            ignorecase = true;
            smartcase = true;
            signcolumn = "yes";
            updatetime = 250;
            timeoutlen = 300;
            splitright = true;
            splitbelow = true;
            list = true;
            listchars = { tab = "» "; trail = "·"; nbsp = "␣"; };
            inccommand = "split";
            cursorline = true;
            scrolloff = 13;
            confirm = true;
            tabstop = 2;
            shiftwidth = 2;
          };

          colorschemes.tokyonight = {
            enable = true;
            settings = {
              style = "night";
              styles.comments.italic = false;
            };
          };

          keymaps = [
            { mode = "n"; key = "<Esc>"; action = "<cmd>nohlsearch<CR>"; }
            {
              mode = "n";
              key = "<leader>q";
              action.__raw = "vim.diagnostic.setloclist";
              options.desc = "Open diagnostic [Q]uickfix list";
            }
            {
              mode = "t";
              key = "<Esc><Esc>";
              action = "<C-\\><C-n>";
              options.desc = "Exit terminal mode";
            }
            # <C-h/j/k/l> window moves come from vim-tmux-navigator (falls back
            # to plain window moves outside tmux).

            # Telescope
            { mode = "n"; key = "<leader>sh"; action.__raw = "require('telescope.builtin').help_tags"; options.desc = "[S]earch [H]elp"; }
            { mode = "n"; key = "<leader>sk"; action.__raw = "require('telescope.builtin').keymaps"; options.desc = "[S]earch [K]eymaps"; }
            { mode = "n"; key = "<leader>sf"; action.__raw = "require('telescope.builtin').find_files"; options.desc = "[S]earch [F]iles"; }
            { mode = "n"; key = "<leader>ss"; action.__raw = "require('telescope.builtin').builtin"; options.desc = "[S]earch [S]elect Telescope"; }
            { mode = "n"; key = "<leader>sw"; action.__raw = "require('telescope.builtin').grep_string"; options.desc = "[S]earch current [W]ord"; }
            { mode = "n"; key = "<leader>sg"; action.__raw = "require('telescope.builtin').live_grep"; options.desc = "[S]earch by [G]rep"; }
            { mode = "n"; key = "<leader>sd"; action.__raw = "require('telescope.builtin').diagnostics"; options.desc = "[S]earch [D]iagnostics"; }
            { mode = "n"; key = "<leader>sr"; action.__raw = "require('telescope.builtin').resume"; options.desc = "[S]earch [R]esume"; }
            { mode = "n"; key = "<leader>s."; action.__raw = "require('telescope.builtin').oldfiles"; options.desc = "[S]earch Recent Files (\".\" for repeat)"; }
            { mode = "n"; key = "<leader><leader>"; action.__raw = "require('telescope.builtin').buffers"; options.desc = "[ ] Find existing buffers"; }
            {
              mode = "n";
              key = "<leader>/";
              action.__raw = ''
                function()
                  require('telescope.builtin').current_buffer_fuzzy_find(require('telescope.themes').get_dropdown {
                    winblend = 10,
                    previewer = false,
                  })
                end
              '';
              options.desc = "[/] Fuzzily search in current buffer";
            }
            {
              mode = "n";
              key = "<leader>s/";
              action.__raw = ''
                function()
                  require('telescope.builtin').live_grep {
                    grep_open_files = true,
                    prompt_title = 'Live Grep in Open Files',
                  }
                end
              '';
              options.desc = "[S]earch [/] in Open Files";
            }
            {
              mode = "n";
              key = "<leader>sn";
              action.__raw = ''
                function()
                  require('telescope.builtin').find_files { cwd = vim.fn.stdpath 'config' }
                end
              '';
              options.desc = "[S]earch [N]eovim files";
            }

            # Conform
            {
              mode = "";
              key = "<leader>f";
              action.__raw = "function() require('conform').format { async = true, lsp_format = 'fallback' } end";
              options.desc = "[F]ormat buffer";
            }

            # Neo-tree
            {
              mode = "n";
              key = "\\";
              action = ":Neotree reveal<CR>";
              options = { desc = "NeoTree reveal"; silent = true; };
            }
          ];

          autoGroups.kickstart-highlight-yank.clear = true;
          autoCmd = [
            {
              event = "TextYankPost";
              desc = "Highlight when yanking (copying) text";
              group = "kickstart-highlight-yank";
              callback.__raw = "function() vim.hl.on_yank() end";
            }
          ];

          diagnostic.settings = {
            severity_sort = true;
            float = { border = "rounded"; source = "if_many"; };
            underline.severity.__raw = "vim.diagnostic.severity.ERROR";
            signs.text.__raw = ''
              {
                [vim.diagnostic.severity.ERROR] = '󰅚 ',
                [vim.diagnostic.severity.WARN] = '󰀪 ',
                [vim.diagnostic.severity.INFO] = '󰋽 ',
                [vim.diagnostic.severity.HINT] = '󰌶 ',
              }
            '';
            virtual_text = {
              source = "if_many";
              spacing = 2;
            };
          };

          plugins = {
            web-devicons.enable = true;
            guess-indent.enable = true;

            gitsigns = {
              enable = true;
              settings.signs = {
                add.text = "+";
                change.text = "~";
                delete.text = "_";
                topdelete.text = "‾";
                changedelete.text = "~";
              };
            };

            tmux-navigator.enable = true;

            neogit.enable = true;
            diffview.enable = true;

            which-key = {
              enable = true;
              settings = {
                delay = 0;
                icons.mappings = true;
                spec = [
                  { __unkeyed-1 = "<leader>s"; group = "[S]earch"; }
                  { __unkeyed-1 = "<leader>t"; group = "[T]oggle"; }
                  { __unkeyed-1 = "<leader>h"; group = "Git [H]unk"; mode = [ "n" "v" ]; }
                ];
              };
            };

            telescope = {
              enable = true;
              extensions = {
                fzf-native.enable = true;
                ui-select = {
                  enable = true;
                  settings.__raw = "{ require('telescope.themes').get_dropdown() }";
                };
              };
            };

            lazydev = {
              enable = true;
              settings.library = [
                { path = "\${3rd}/luv/library"; words = [ "vim%.uv" ]; }
              ];
            };

            lspconfig.enable = true;
            fidget.enable = true;

            conform-nvim = {
              enable = true;
              settings = {
                notify_on_error = false;
                format_on_save.__raw = ''
                  function(bufnr)
                    -- nix: nixd would reformat whole files with nixfmt, which
                    -- this repo doesn't use; format manually with <leader>f.
                    local disable_filetypes = { c = true, cpp = true, nix = true }
                    if disable_filetypes[vim.bo[bufnr].filetype] then
                      return nil
                    else
                      return {
                        timeout_ms = 500,
                        lsp_format = 'fallback',
                      }
                    end
                  end
                '';
                formatters_by_ft.lua = [ "stylua" ];
                formatters_by_ft.json = [ "jq" ];
              };
            };

            luasnip.enable = true;

            blink-cmp = {
              enable = true;
              settings = {
                keymap.preset = "default";
                appearance.nerd_font_variant = "mono";
                completion.documentation = {
                  auto_show = false;
                  auto_show_delay_ms = 500;
                };
                sources = {
                  default = [ "lsp" "path" "snippets" "lazydev" ];
                  providers.lazydev = {
                    module = "lazydev.integrations.blink";
                    score_offset = 100;
                  };
                };
                snippets.preset = "luasnip";
                fuzzy.implementation = "lua";
                signature.enabled = true;
              };
            };

            todo-comments = {
              enable = true;
              settings.signs = false;
            };

            mini = {
              enable = true;
              modules = {
                ai.n_lines = 500;
                surround = { };
                statusline.use_icons = true;
              };
              luaConfig.post = ''
                require('mini.statusline').section_location = function()
                  return '%2l:%-2v'
                end
              '';
            };

            # All nixpkgs grammars (replaces ensure_installed + auto_install).
            treesitter = {
              enable = true;
              highlight = {
                enable = true;
                enableVimSyntax = [ "ruby" ];
              };
              indent = {
                enable = true;
                disable = [ "ruby" ];
              };
            };

            neo-tree = {
              enable = true;
              settings.filesystem = {
                filtered_items.visible = true;
                window.mappings."\\" = "close_window";
              };
            };
          };

          lsp.servers = {
            # Same blink capabilities kickstart passed to every server.
            "*".config.capabilities.__raw = "require('blink.cmp').get_lsp_capabilities()";

            pyright = {
              enable = true;
              config.settings.python.analysis = {
                typeCheckingMode = "basic";
                autoImportCompletions = true;
              };
            };

            ruff = {
              enable = true;
              config = {
                filetypes = [ "python" ];
                init_options.settings = {
                  configurationPreference = "filesystemFirst"; # local pyproject/ruff.toml first
                  lint.preview = true;
                  format.preview = true;
                };
              };
            };

            lua_ls = {
              enable = true;
              config.settings.Lua.completion.callSnippet = "Replace";
            };

            nixd = {
              enable = true;
              config.settings.nixd = {
                nixpkgs.expr = "import <nixpkgs> { }";
                formatting.command = [ "nixfmt" ];
              };
            };
          };

          extraPackages = with pkgs; [
            stylua
            jq
            nixfmt
            ripgrep
            fd
          ];

          extraConfigLua = ''
            -- Sync clipboard between OS and Neovim (scheduled: can slow startup).
            vim.schedule(function()
              vim.o.clipboard = 'unnamedplus'
            end)

            vim.api.nvim_create_autocmd('LspAttach', {
              group = vim.api.nvim_create_augroup('kickstart-lsp-attach', { clear = true }),
              callback = function(event)
                local map = function(keys, func, desc, mode)
                  mode = mode or 'n'
                  vim.keymap.set(mode, keys, func, { buffer = event.buf, desc = 'LSP: ' .. desc })
                end
                local builtin = require 'telescope.builtin'

                map('grn', vim.lsp.buf.rename, '[R]e[n]ame')
                map('gra', vim.lsp.buf.code_action, '[G]oto Code [A]ction', { 'n', 'x' })
                map('grr', builtin.lsp_references, '[G]oto [R]eferences')
                map('gri', builtin.lsp_implementations, '[G]oto [I]mplementation')
                map('grd', builtin.lsp_definitions, '[G]oto [D]efinition')
                map('grD', vim.lsp.buf.declaration, '[G]oto [D]eclaration')
                map('gO', builtin.lsp_document_symbols, 'Open Document Symbols')
                map('gW', builtin.lsp_dynamic_workspace_symbols, 'Open Workspace Symbols')
                map('grt', builtin.lsp_type_definitions, '[G]oto [T]ype Definition')

                local client = vim.lsp.get_client_by_id(event.data.client_id)
                if client and client:supports_method(vim.lsp.protocol.Methods.textDocument_documentHighlight, event.buf) then
                  local highlight_augroup = vim.api.nvim_create_augroup('kickstart-lsp-highlight', { clear = false })
                  vim.api.nvim_create_autocmd({ 'CursorHold', 'CursorHoldI' }, {
                    buffer = event.buf,
                    group = highlight_augroup,
                    callback = vim.lsp.buf.document_highlight,
                  })
                  vim.api.nvim_create_autocmd({ 'CursorMoved', 'CursorMovedI' }, {
                    buffer = event.buf,
                    group = highlight_augroup,
                    callback = vim.lsp.buf.clear_references,
                  })
                  vim.api.nvim_create_autocmd('LspDetach', {
                    group = vim.api.nvim_create_augroup('kickstart-lsp-detach', { clear = true }),
                    callback = function(event2)
                      vim.lsp.buf.clear_references()
                      vim.api.nvim_clear_autocmds { group = 'kickstart-lsp-highlight', buffer = event2.buf }
                    end,
                  })
                end

                if client and client:supports_method(vim.lsp.protocol.Methods.textDocument_inlayHint, event.buf) then
                  map('<leader>th', function()
                    vim.lsp.inlay_hint.enable(not vim.lsp.inlay_hint.is_enabled { bufnr = event.buf })
                  end, '[T]oggle Inlay [H]ints')
                end
              end,
            })
          '';
        };
      };
  };
}
