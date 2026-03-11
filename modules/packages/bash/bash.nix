{ ... }: {
  flake.nixosModules.bash = { config, lib, ... }:
    lib.mkIf config.dotfiles.programs.bash.enable {
      home-manager.users.${config.dotfiles.user.name} = { ... }: {
        programs.bash = {
          enable = true;
          initExtra = ''
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
    };
}
