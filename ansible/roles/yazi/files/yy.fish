# Managed by Ansible. Equivalent of programs.yazi.shellWrapperName = "yy":
# leaves the shell in whatever directory yazi was in when it exited.
function yy --description "Open yazi and cd to its last directory on exit"
    set -l tmp (mktemp -t "yazi-cwd.XXXXXX")
    yazi $argv --cwd-file="$tmp"
    if set -l cwd (command cat -- "$tmp"); and [ -n "$cwd" ]; and [ "$cwd" != "$PWD" ]
        builtin cd -- "$cwd"
    end
    rm -f -- "$tmp"
end
