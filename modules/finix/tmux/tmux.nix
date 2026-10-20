{ ... }: {
  # home-manager programs.tmux (prefix C-a, mouse, base-index 1, ...) as a
  # plain tmux.conf; key bindings follow the window manager direction keys.
  flake.finixModules.tmux = { config, lib, pkgs, ... }:
    let
      dirs = config.dotfiles.windowManager.settings;
      left  = lib.toLower dirs.left;
      right = lib.toLower dirs.right;
      up    = lib.toLower dirs.up;
      down  = lib.toLower dirs.down;
    in lib.mkIf config.dotfiles.programs.tmux.enable {
      environment.systemPackages = [ pkgs.tmux ];

      hjem.users.${config.dotfiles.user.name}.xdg.config.files."tmux/tmux.conf".text = ''
        set -g default-terminal "tmux-256color"
        set -g base-index 1
        setw -g pane-base-index 1
        set -g mouse on
        set -s escape-time 0
        set -g history-limit 10000

        unbind C-b
        set -g prefix C-a
        bind -N "Send the prefix key through to the application" C-a send-prefix

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
        bind -r ${dirs.left}  resize-pane -L 5
        bind -r ${dirs.down}  resize-pane -D 5
        bind -r ${dirs.up}    resize-pane -U 5
        bind -r ${dirs.right} resize-pane -R 5

        # Reload config
        bind r source-file ~/.config/tmux/tmux.conf \; display "Config reloaded"

        # Window switching
        ${lib.concatMapStrings (i: "bind -n M-${toString i} select-window -t ${toString i}\n") (lib.range 1 9)}
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
}
