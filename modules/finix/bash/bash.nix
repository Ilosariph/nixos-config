{ ... }: {
  flake.finixModules.bash = { config, lib, ... }:
    lib.mkIf config.dotfiles.programs.bash.enable {
      hjem.users.${config.dotfiles.user.name}.files = {
        ".bash_profile".text = ''
          [ -f ~/.bashrc ] && . ~/.bashrc
        '';
        ".bashrc".text = ''
          [ -f /etc/bashrc ] && . /etc/bashrc

          if test -n "$KITTY_INSTALLATION_DIR"; then
            export KITTY_SHELL_INTEGRATION="enabled"
            source "$KITTY_INSTALLATION_DIR/shell-integration/bash/kitty.bash"
          fi

          # Launch fish if available and this is an interactive shell
          if [[ $- == *i* ]] && command -v fish &>/dev/null; then
            exec fish
          fi
        '';
      };
    };
}
