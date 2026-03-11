{ ... }: {
  flake.nixosModules.tmux = { config, lib, pkgs, ... }:
    lib.mkIf config.dotfiles.programs.tmux.enable {
      home-manager.users.${config.dotfiles.user.name} = { ... }: {
        programs.tmux = {
          enable = true;
          prefix = "C-a";
          mouse = true;
          baseIndex = 1;
          escapeTime = 0;
          historyLimit = 10000;
          terminal = "tmux-256color";

          extraConfig =
            let
              left  = lib.strings.toLower config.dotfiles.windowManager.settings.left;
              right = lib.strings.toLower config.dotfiles.windowManager.settings.right;
              up    = lib.strings.toLower config.dotfiles.windowManager.settings.up;
              down  = lib.strings.toLower config.dotfiles.windowManager.settings.down;
              LEFT  = config.dotfiles.windowManager.settings.left;
              RIGHT = config.dotfiles.windowManager.settings.right;
              UP    = config.dotfiles.windowManager.settings.up;
              DOWN  = config.dotfiles.windowManager.settings.down;
            in ''
            # True colour support
            set -ag terminal-overrides ",xterm-256color:RGB"

            # Split panes with | and -
            bind | split-window -h -c "#{pane_current_path}"
            bind - split-window -v -c "#{pane_current_path}"
            unbind '"'
            unbind %

            # New window keeps current path
            bind c new-window -c "#{pane_current_path}"

            # Pane navigation (matches window manager directional keys)
            bind ${left}  select-pane -L
            bind ${down}  select-pane -D
            bind ${up}    select-pane -U
            bind ${right} select-pane -R

            # Pane resizing (uppercase = shift)
            bind -r ${LEFT}  resize-pane -L 5
            bind -r ${DOWN}  resize-pane -D 5
            bind -r ${UP}    resize-pane -U 5
            bind -r ${RIGHT} resize-pane -R 5

            # Reload config
            bind r source-file ~/.config/tmux/tmux.conf \; display "Config reloaded"

            # Window switching
            bind -n M-1 select-window -t 1
            bind -n M-2 select-window -t 2
            bind -n M-3 select-window -t 3
            bind -n M-4 select-window -t 4
            bind -n M-5 select-window -t 5
            bind -n M-6 select-window -t 6
            bind -n M-7 select-window -t 7
            bind -n M-8 select-window -t 8
            bind -n M-9 select-window -t 9

            # Status bar
            set -g status-position bottom
            set -g status-style "bg=colour235,fg=colour136"
            set -g status-left "#[fg=colour166,bold] #S "
            set -g status-right "#[fg=colour136] %H:%M  %Y-%m-%d "
            set -g window-status-current-style "fg=colour166,bold"
            set -g window-status-format " #I:#W "
            set -g window-status-current-format " #I:#W "

            # Pane border
            set -g pane-border-style "fg=colour235"
            set -g pane-active-border-style "fg=colour166"
          '';
        };
      };
    };
}
