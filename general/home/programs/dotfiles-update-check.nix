{ pkgs, lib, ... }:
let
  dotfilesUpdateCheck = pkgs.writeShellApplication {
    name = "dotfiles-update-check";
    runtimeInputs = [ pkgs.git pkgs.libnotify ];
    text = ''
      # When called with --startup, wait for the notification daemon and
      # network to settle before doing anything (used by Hyprland exec-once).
      if [[ "''${1:-}" == "--startup" ]]; then
        sleep 8
      fi

      DOTFILES_DIR="$HOME/.dotfiles"

      if [ ! -d "$DOTFILES_DIR" ]; then
        exit 0
      fi

      cd "$DOTFILES_DIR" || exit 0

      # Fetch from remote; bail out silently if offline or no remote configured
      git fetch --quiet 2>/dev/null || exit 0

      BRANCH=$(git rev-parse --abbrev-ref HEAD 2>/dev/null)
      LOCAL=$(git rev-parse HEAD 2>/dev/null)
      REMOTE=$(git rev-parse "origin/''${BRANCH}" 2>/dev/null || true)

      # If the remote ref doesn't exist yet, nothing to compare
      if [ -z "$REMOTE" ]; then
        exit 0
      fi

      AHEAD=$(git rev-list --count "HEAD..origin/''${BRANCH}" 2>/dev/null || echo 0)

      if [ "$AHEAD" -gt 0 ]; then
        MSG="''${AHEAD} new commit(s) on ''${BRANCH}. Run 'git pull' in ~/.dotfiles to update."

        if [ -n "''${WAYLAND_DISPLAY:-}" ] || [ -n "''${DISPLAY:-}" ]; then
          notify-send \
            --urgency=normal \
            --icon=software-update-available \
            "Dotfiles Update Available" \
            "$MSG"
        else
          printf '\n\033[1;33m dotfiles:\033[0m %s\n\n' "$MSG"
        fi
      fi
    '';
  };
in {
  home.packages = [ dotfilesUpdateCheck ];

  # Run on login shells so updates are announced when SSHing in (no-DE use).
  # On desktop the Hyprland exec-once entry handles it instead.
  programs.bash = {
    enable = lib.mkDefault true;
    profileExtra = ''
      ${dotfilesUpdateCheck}/bin/dotfiles-update-check
    '';
  };
}
