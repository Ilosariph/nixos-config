{ ... }: {
  # Microphone mute toggle: a single `mic-mute` command that any controller (niri
  # keybind, Streamdeck, waybar module, terminal, scripts) can call, so all of them
  # share one implementation and one notion of state.
  #
  # It operates on the default physical source. The mic effects chain
  # (audio-routing.nix) captures from the default source, so muting it also
  # silences the virtual "source-mic" — no separate handling needed, and it works
  # the same in every dotfiles.audio.routing mode.
  flake.nixosModules.mic-mute = { config, lib, pkgs, ... }:
    let
      micMuteScript = pkgs.writeShellApplication {
        name = "mic-mute";
        runtimeInputs = [ pkgs.wireplumber pkgs.libnotify ];
        text = ''
          # mic-mute [toggle|mute|unmute|status]
          #   toggle (default) — flip mute on the default source
          #   mute / unmute    — set an explicit state (idempotent, for scripting)
          #   status           — print "muted" or "unmuted" (for statusbar modules)
          action="''${1:-toggle}"

          case "$action" in
            toggle) wpctl set-mute @DEFAULT_AUDIO_SOURCE@ toggle ;;
            mute)   wpctl set-mute @DEFAULT_AUDIO_SOURCE@ 1 ;;
            unmute) wpctl set-mute @DEFAULT_AUDIO_SOURCE@ 0 ;;
            status) ;;
            *)
              echo "usage: mic-mute [toggle|mute|unmute|status]" >&2
              exit 2
              ;;
          esac

          if wpctl get-volume @DEFAULT_AUDIO_SOURCE@ | grep -q MUTED; then
            state="muted"
          else
            state="unmuted"
          fi

          if [ "$action" = "status" ]; then
            echo "$state"
          else
            if [ "$state" = "muted" ]; then
              notify-send -u low "Microphone" "󰍭 Muted"
            else
              notify-send -u low "Microphone" "󰍬 Unmuted"
            fi
          fi
        '';
      };
    in
    lib.mkIf config.dotfiles.desktop.enable {
      environment.systemPackages = [ micMuteScript ];
    };
}
