{ pkgs, ... }:
{
  programs.zed-editor = {
    enable = true;
    extensions = [
      "git-firefly"
      "lua"
      "nix"
      "tokyo-night"
    ];

    userSettings = {
      agent = {
        use_modifier_to_send = true;
        button = true;
        model_parameters = [];
      };
      outline_panel = {
        button = true;
      };
      project_panel = {
        sort_mode = "directories_first";
        hide_root = false;
        scrollbar = {
          show = "auto";
        };
        file_icons = true;
        entry_spacing = "standard";
        dock = "left";
      };
      window_decorations = "client";
      bottom_dock_layout = "contained";
      preview_tabs = {
        enabled = true;
        enable_preview_from_file_finder = false;
      };
      tabs = {
        show_close_button = "hidden";
        file_icons = false;
        git_status = true;
      };
      title_bar = {
        show_menus = true;
        show_branch_icon = false;
      };
      close_on_file_delete = true;
      use_smartcase_search = true;
      languages = {
        Nix = {
          tab_size = 2;
        };
      };
      show_whitespaces = "selection";
      tab_size = 4;
      minimap = {
        show = "never";
      };
      autosave = {
        after_delay = {
          milliseconds = 1000;
        };
      };
      ui_font_family = ".ZedSans";
      buffer_font_family = "JetBrains Mono";
      relative_line_numbers = "enabled";
      vim_mode = true;
      base_keymap = "JetBrains";
      icon_theme = "Zed (Default)";
      ui_font_size = 16;
      buffer_font_size = 15;
      theme = "Tokyo Night Moon";
    };

    userKeymaps = [
      {
        context = "Workspace";
        bindings = {
          # "shift shift" = "file_finder::Toggle";
        };
      }
      {
        context = "Editor && vim_mode == insert";
        bindings = {
          # "j k" = "vim::NormalBefore";
        };
      }
    ];
  };
}
