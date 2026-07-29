# Managed by Ansible. From programs.bash.initExtra in modules/packages/bash/bash.nix.
if [ -n "$KITTY_INSTALLATION_DIR" ]; then
    export KITTY_SHELL_INTEGRATION="enabled"
    # shellcheck source=/dev/null
    source "$KITTY_INSTALLATION_DIR/shell-integration/bash/kitty.bash"
fi
