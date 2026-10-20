# mic-mute [toggle|mute|unmute|status]
#   toggle (default) — flip mute on the default source
#   mute / unmute    — set an explicit state (idempotent, for scripting)
#   status           — print "muted" or "unmuted" (for statusbar modules)
action="${1:-toggle}"

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
