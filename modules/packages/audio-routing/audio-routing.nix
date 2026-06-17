{ ... }: {
  flake.nixosModules.audio-routing = { config, lib, pkgs, ... }:
    let
      cfg = config.dotfiles.audio;

      # Entry node of the effects bus (compressor stage). Effected sinks loop back here.
      fxSink = "sink-fx";
      # Compressor stage feeds the limiter stage, which feeds the master sink.
      fxLimSink = "sink-fxlim";
      # Master mixing point: every sink (effected and direct) converges here, so its volume
      # is a single global output level independent of the physical device. One loopback
      # carries the master monitor to the current default (physical) device.
      masterSink = "sink-master";

      anyEffects = lib.any (s: s.effects) cfg.sinks;

      # Manual output-device switcher: pick a physical sink from a wofi menu and make it the
      # default. Everything hardware-facing (the effects output + direct loopbacks) follows the
      # default, so this one action moves all audio. wpctl persists the choice across reboots,
      # and falls back to another connected device if the chosen one is missing.
      audioOutputScript = pkgs.writeShellApplication {
        name = "audio-output";
        runtimeInputs = [ pkgs.jq pkgs.wofi pkgs.pipewire pkgs.wireplumber pkgs.libnotify ];
        text = ''
          # Physical output sinks as "id<TAB>description" (exclude our sink-* virtuals).
          mapfile -t entries < <(pw-dump | jq -r '
            .[] | select(.type=="PipeWire:Interface:Node")
                | select(.info.props."media.class"=="Audio/Sink")
                | select(.info.props."node.name" | test("^(alsa_output|bluez_output)"))
                | "\(.id)\t\(.info.props."node.description" // .info.props."node.name")"')

          if [ "''${#entries[@]}" -eq 0 ]; then
            notify-send "Audio output" "No physical output devices found"
            exit 1
          fi

          choice=$(printf '%s\n' "''${entries[@]}" | cut -f2- | wofi --dmenu -p "Output device") || exit 0
          [ -n "$choice" ] || exit 0
          id=$(printf '%s\n' "''${entries[@]}" | awk -F'\t' -v d="$choice" '$2==d{print $1; exit}')
          [ -n "$id" ] || exit 1

          wpctl set-default "$id"
          notify-send "Audio output" "→ $choice"
        '';
      };

      mkNullSink = { name, description, ... }: {
        factory = "adapter";
        args = {
          "factory.name" = "support.null-audio-sink";
          "media.class" = "Audio/Sink";
          "node.name" = "sink-${name}";
          "node.description" = description;
          "audio.position" = [ "FL" "FR" ];
          # Monitor output respects sink volume/mute, so vol ctrl on the sink
          # propagates through the loopback to the physical output.
          "monitor.channel-volumes" = true;
          # Keep virtual sinks out of automatic default-device selection so a real
          # output device is always chosen as the default (apps reach these via rules).
          "priority.session" = 100;
          "priority.driver" = 100;
        };
      };

      # Capture from the monitor of a null sink and play it back.
      # stream.capture.sink = true connects the capture side to the sink's monitor output.
      # Effected sinks are pinned into the internal effects bus (fxSink). Direct sinks are
      # left unpinned so they follow the current default device (and thus the output switcher).
      mkLoopback = { name, description, effects, ... }:
        {
          name = "libpipewire-module-loopback";
          args = {
            "node.name" = "loopback-${name}";
            "capture.props" = {
              "node.name" = "loopback-${name}-cap";
              "node.target" = "sink-${name}";
              "stream.capture.sink" = true;
              "audio.position" = [ "FL" "FR" ];
            };
            "playback.props" = {
              "node.name" = "loopback-${name}-play";
              "audio.position" = [ "FL" "FR" ];
            } // (if effects then {
              # Pin into the effects bus (an internal virtual sink that never changes).
              "target.object" = fxSink;
            } else {
              # Direct (uncompressed) sink: bypass the effects bus but still converge on the
              # master sink so the global volume applies. Friendly name for mixers.
              "target.object" = masterSink;
              "node.description" = "${description} (direct)";
            });
          };
        };

      # A single-plugin filter-chain published as an Audio/Sink. Keeping one plugin per
      # chain means PipeWire derives the chain in/out from the plugin's own ports, so no
      # inter-node link names are needed. The playback side is pinned to `target` when set;
      # an empty target lets it follow the default device.
      #
      # LSP plugins are made discoverable to PipeWire via services.pipewire.extraLv2Packages
      # below (LV2 URIs are version-independent, unlike the versioned LADSPA .so filename).
      #
      # NOTE: `control` keys are LV2 port *symbols* (the short codes from
      # `lv2info <uri>`, e.g. "at"/"cr"/"mk"), NOT the display names — PipeWire's
      # filter-chain matches symbols. LSP gain/threshold ports are linear coefficients
      # (e.g. 0.1259 ≈ -18 dB, 1.585 ≈ +4 dB); times are in ms. A clean run logs no
      # "control ... can not be set" lines (journalctl --user -u pipewire).
      mkFilter = { mediaName, description, sinkNode, outNode, target, uri, control ? { }, outDescription ? null }: {
        name = "libpipewire-module-filter-chain";
        args = {
          "node.description" = description;
          "media.name" = mediaName;
          "filter.graph" = {
            nodes = [
              {
                type = "lv2";
                name = mediaName;
                plugin = uri;
                inherit control;
              }
            ];
          };
          "capture.props" = {
            "node.name" = sinkNode;
            "media.class" = "Audio/Sink";
            "audio.position" = [ "FL" "FR" ];
            # Internal bus sink: keep out of default-device selection.
            "priority.session" = 100;
            "priority.driver" = 100;
          };
          "playback.props" = {
            "node.name" = outNode;
            "audio.position" = [ "FL" "FR" ];
          } // lib.optionalAttrs (outDescription != null) {
            "node.description" = outDescription;
          } // lib.optionalAttrs (target != "") {
            "target.object" = target;
          };
        };
      };

      # Compressor + limiter effects bus. Values translated from the EasyEffects
      # `output-comp` preset (downward compressor ~4:1 @ -12 dB, brickwall limiter).
      # See the NOTE on mkFilter about verifying control names with `lv2info`.
      fxCompressor = mkFilter {
        mediaName = "fx-comp";
        description = "Effects bus: compressor";
        sinkNode = fxSink;
        outNode = "fx-comp-out";
        target = fxLimSink;
        uri = "http://lsp-plug.in/plugins/lv2/compressor_stereo";
        # Gentle downward leveling to even out loudness across apps, with makeup to
        # restore unity (no upward stage — that caused the start-spike in EasyEffects).
        control = {
          "enabled" = 1.0;
          "cm" = 0.0;     # compression mode: Downward
          "al" = 0.1259;  # attack threshold ≈ -18 dB
          "cr" = 2.9;     # ratio 2.5:1
          "at" = 15.0;    # attack time (ms)
          "rt" = 250.0;   # release time (ms)
          "mk" = 2.300;   # makeup gain ≈ +4 dB
        };
      };

      fxLimiter = mkFilter {
        mediaName = "fx-lim";
        description = "Effects bus: limiter";
        sinkNode = fxLimSink;
        outNode = "fx-lim-out";
        # Feed the master sink (which in turn follows the default device).
        target = masterSink;
        outDescription = "Effects output";
        uri = "http://lsp-plug.in/plugins/lv2/limiter_stereo";
        # Brick-wall safety limiter just below 0 dBFS to catch peaks.
        control = {
          "enabled" = 1.0;
          "th" = 0.8913;  # threshold ≈ -1 dBFS
          "lk" = 5.0;     # lookahead (ms)
        };
      };

      # Master sink + the single hardware-facing loopback. The null sink is the global volume
      # control (its monitor is volume-scaled); the loopback plays that monitor to the current
      # default (physical) device, so the output switcher still moves all audio at once. Point
      # the Streamdeck's output-volume control at "sink-master".
      masterNullSink = mkNullSink { name = "master"; description = "Master Output"; };
      masterLoopback = {
        name = "libpipewire-module-loopback";
        args = {
          "node.name" = "loopback-master";
          "capture.props" = {
            "node.name" = "loopback-master-cap";
            "node.target" = masterSink;
            "stream.capture.sink" = true;
            "audio.position" = [ "FL" "FR" ];
          };
          "playback.props" = {
            "node.name" = "loopback-master-play";
            "node.description" = "Master output";
            "audio.position" = [ "FL" "FR" ];
            # No target.object -> follows the default (physical) device / output switcher.
          };
        };
      };

      # The catch-all sink (flagged `default`, else the first configured sink). Every app lands
      # here unless a more specific rule or a manual move sends it elsewhere.
      defaultSinks = lib.filter (s: s.default) cfg.sinks;
      defaultSinkName =
        if defaultSinks != [ ] then "sink-${(lib.head defaultSinks).name}"
        else if cfg.sinks != [ ] then "sink-${(lib.head cfg.sinks).name}"
        else null;

      # PulseAudio-client routing. The catch-all sends every app to the default (effects) sink;
      # per-sink rules override it for specific apps (e.g. Spotify -> music). pulse.rules only
      # match real pulse clients, never the internal loopback/filter nodes, so they can't create
      # a feedback loop. Streams can still be moved at runtime (pavucontrol / in-app), which
      # overrides these defaults.
      pulseRules =
        (lib.optional (defaultSinkName != null) {
          matches = [ { "application.name" = "~.+"; } ];
          actions.update-props."target.object" = defaultSinkName;
        })
        ++ lib.concatMap
          (s: lib.optional (s.apps != [ ]) {
            matches = s.apps;
            actions.update-props."target.object" = "sink-${s.name}";
          })
          cfg.sinks;

    in
    lib.mkIf config.dotfiles.desktop.enable (lib.mkMerge [

      # EasyEffects provides the mic processing chain (and, in pulsemeeter mode, the output
      # compressor/limiter). The native filter-chain replaces it for output in virtual mode.
      (lib.mkIf (cfg.routing != "none") {
        dotfiles.audio.easyeffects.enable = lib.mkDefault true;
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

        # qpwgraph for manual inspection (not auto-launched); audio-output switcher for
        # manually moving all outputs to another physical device (e.g. BT headphones).
        environment.systemPackages = [ pkgs.qpwgraph audioOutputScript ];

        # Make LSP's LV2 plugins discoverable to the PipeWire filter-chain. This is the
        # supported NixOS mechanism and is version-independent (no LADSPA .so path needed).
        services.pipewire.extraLv2Packages = lib.mkIf anyEffects [ pkgs.lsp-plugins ];

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
            ++ lib.optionals anyEffects [ fxCompressor fxLimiter ];
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
        services.pipewire.wireplumber.extraConfig = lib.mkIf (cfg.outputSink != "") {
          "51-default-output-priority"."monitor.alsa.rules" = [
            {
              matches = [ { "node.name" = cfg.outputSink; } ];
              actions.update-props = {
                "priority.session" = 2000;
                "priority.driver" = 2000;
              };
            }
          ];
        };

        # Expose the configurable volume ceiling through the PulseAudio compat layer.
        # StreamController and pactl honour this limit when setting sink volumes.
        # Default is 1.0 (100%); set dotfiles.audio.volumeLimit = 1.5 for 150%.
        services.pipewire.extraConfig.pipewire-pulse."10-volume-limit" = {
          "stream.properties"."volume.limit" = cfg.volumeLimit;
        };
      })
    ]);
}
