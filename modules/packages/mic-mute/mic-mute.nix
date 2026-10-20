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
        text = builtins.readFile ./mic-mute.sh;
      };
    in
    lib.mkIf config.dotfiles.desktop.enable {
      environment.systemPackages = [ micMuteScript ];
    };
}
