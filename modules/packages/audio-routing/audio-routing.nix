{ ... }: {
  flake.nixosModules.audio-routing = { config, lib, pkgs, ... }:
    let
      cfg = config.dotfiles.audio;
      audio = import ./_audio.nix { inherit lib pkgs cfg; };
      inherit (audio)
        audioOutputScript
        audioInputScript
        audioDeviceScript
        anyEffects
        mkNullSink
        masterNullSink
        mkLoopback
        masterLoopback
        mkEffectsChain
        effectsSinks
        micChain
        pulseRules
        ;
    in
    lib.mkIf config.dotfiles.desktop.enable (lib.mkMerge [

      # In pulsemeeter mode EasyEffects still provides the output compressor/limiter and
      # the mic chain. In pipewire-virtual mode both are native filter-chains; the mic
      # chain is enabled by default and EasyEffects is no longer pulled in.
      (lib.mkIf (cfg.routing == "pulsemeeter") {
        dotfiles.audio.easyeffects.enable = lib.mkDefault true;
      })
      (lib.mkIf (cfg.routing == "pipewire-virtual") {
        dotfiles.audio.micEffects.enable = lib.mkDefault true;
      })

      # ── pulsemeeter mode ──────────────────────────────────────────────────────
      (lib.mkIf (cfg.routing == "pulsemeeter") {
        environment.systemPackages = with pkgs; [
          pulsemeeter
          qpwgraph
        ];
      })

      # ── pipewire-virtual mode ─────────────────────────────────────────────────
      (lib.mkIf (cfg.routing == "pipewire-virtual") {

        # qpwgraph for manual inspection (not auto-launched); switchers for moving all
        # outputs (audio-output), the default mic (audio-input), or both ends at once
        # for a single device (audio-device).
        environment.systemPackages = [
          pkgs.qpwgraph
          audioOutputScript
          audioInputScript
          audioDeviceScript
        ];

        # Make LSP's LV2 plugins discoverable to the PipeWire filter-chain. This is the
        # supported NixOS mechanism and is version-independent (no LADSPA .so path needed).
        services.pipewire.extraLv2Packages =
          lib.mkIf (anyEffects || cfg.micEffects.enable) [ pkgs.lsp-plugins ];

        # Null sinks + their loopbacks, plus the effects-bus filter-chains when any sink
        # routes through effects. Loopback playback nodes show up as individual streams in
        # volume mixers (pavucontrol, StreamController) so each virtual sink has its own level.
        services.pipewire.extraConfig.pipewire."10-virtual-sinks" = {
          "context.objects" =
            (map mkNullSink cfg.sinks)
            ++ lib.optional (cfg.sinks != [ ]) masterNullSink;
          "context.modules" =
            (map mkLoopback cfg.sinks)
            ++ lib.optional (cfg.sinks != [ ]) masterLoopback
            ++ lib.concatMap mkEffectsChain effectsSinks;
        };

        # Microphone effects chain: physical default source → gate → de-esser → EQ →
        # compressor → source-mic (the static virtual source apps consume). Disable by
        # setting dotfiles.audio.micEffects.enable = false.
        services.pipewire.extraConfig.pipewire."20-mic-chain" =
          lib.mkIf cfg.micEffects.enable {
            "context.modules" = micChain;
          };

        # Route PulseAudio clients to the virtual sinks (see pulseRules above). The default
        # device is left to WirePlumber's normal selection (a physical device, since the virtual
        # sinks are deprioritised) and is switchable/persistent via `audio-output` / wpctl.
        services.pipewire.extraConfig.pipewire-pulse."20-app-routing" = {
          "pulse.rules" = pulseRules;
        };

        # Prefer outputSink as the default device so a fresh state picks it over other real
        # outputs (e.g. HDMI/DP monitor audio). An explicit `wpctl set-default` choice (the
        # output switcher) still wins and persists; if it disconnects, selection falls back to
        # this highest-priority device.
        services.pipewire.wireplumber.extraConfig = lib.mkMerge [
          (lib.mkIf (cfg.outputSink != "") {
            "51-default-output-priority"."monitor.alsa.rules" = [
              {
                matches = [ { "node.name" = cfg.outputSink; } ];
                actions.update-props = {
                  "priority.session" = 2000;
                  "priority.driver" = 2000;
                };
              }
            ];
          })
          (lib.mkIf (cfg.inputSource != "") {
            "52-default-input-priority"."monitor.alsa.rules" = [
              {
                matches = [ { "node.name" = cfg.inputSource; } ];
                actions.update-props = {
                  "priority.session" = 2000;
                  "priority.driver" = 2000;
                };
              }
            ];
          })
        ];

        # Expose the configurable volume ceiling through the PulseAudio compat layer.
        # StreamController and pactl honour this limit when setting sink volumes.
        # Default is 1.0 (100%); set dotfiles.audio.volumeLimit = 1.5 for 150%.
        services.pipewire.extraConfig.pipewire-pulse."10-volume-limit" = {
          "stream.properties"."volume.limit" = cfg.volumeLimit;
        };
      })
    ]);
}
