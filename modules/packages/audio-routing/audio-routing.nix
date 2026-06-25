{ ... }: {
  flake.nixosModules.audio-routing = { config, lib, pkgs, ... }:
    let
      cfg = config.dotfiles.audio;

      # Master mixing point: every sink (effected and direct) converges here, so its volume
      # is a single global output level independent of the physical device. One loopback
      # carries the master monitor to the current default (physical) device.
      masterSink = "sink-master";

      # Each effected sink gets its OWN compressor+limiter chain (independent dynamics, so
      # e.g. comms compression never ducks app audio). Per-sink stage entry nodes:
      fxEntryFor = name: "sink-fx-${name}";       # compressor input
      fxLimEntryFor = name: "sink-fxlim-${name}"; # limiter input

      effectsSinks = lib.filter (s: s.effects) cfg.sinks;
      anyEffects = effectsSinks != [ ];

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
      # Effected sinks are pinned into their own compressor input; direct sinks go straight to
      # the master sink. Either way audio converges on the master sink.
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
              # Pin into this sink's own compressor input (an internal virtual sink).
              "target.object" = fxEntryFor name;
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

      # Per-channel compressor+limiter. Each effected sink gets its own pair of LSP filter
      # chains:  <sink> loopback -> sink-fx-<name> -[compressor]-> sink-fxlim-<name>
      # -[limiter]-> master. Separate instances keep each channel's dynamics isolated.
      #
      # Control values are shared defaults (translated from the EasyEffects output-comp preset:
      # gentle downward compressor + makeup, brick-wall limiter). See the NOTE on mkFilter for
      # control symbols/units. To tune a channel differently, give it its own control set here.
      compressorControl = {
        "enabled" = 1.0;
        "cm" = 0.0;     # compression mode: Downward
        "al" = 0.1259;  # attack threshold ≈ -18 dB
        "cr" = 2.9;     # ratio
        "at" = 15.0;    # attack time (ms)
        "rt" = 250.0;   # release time (ms)
        "mk" = 2.300;   # makeup gain
      };
      limiterControl = {
        "enabled" = 1.0;
        "th" = 0.8913;  # threshold ≈ -1 dBFS
        "lk" = 5.0;     # lookahead (ms)
      };

      # The two filter-chains (compressor then limiter) for one effected sink.
      mkEffectsChain = s: [
        (mkFilter {
          mediaName = "fx-comp-${s.name}";
          description = "${s.description} bus: compressor";
          sinkNode = fxEntryFor s.name;
          outNode = "fx-comp-${s.name}-out";
          target = fxLimEntryFor s.name;
          uri = "http://lsp-plug.in/plugins/lv2/compressor_stereo";
          control = compressorControl;
        })
        (mkFilter {
          mediaName = "fx-lim-${s.name}";
          description = "${s.description} bus: limiter";
          sinkNode = fxLimEntryFor s.name;
          outNode = "fx-lim-${s.name}-out";
          # Feed the master sink (which in turn follows the default device).
          target = masterSink;
          outDescription = "${s.description} effects output";
          uri = "http://lsp-plug.in/plugins/lv2/limiter_stereo";
          control = limiterControl;
        })
      ];

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

      # ── Microphone effects chain ─────────────────────────────────────────────
      # Mirrors the output filter-chain pattern, but exposing a virtual SOURCE instead
      # of a virtual sink. Stages are chained source-to-source (gate → deesser → eq →
      # compressor) and the final stage publishes `source-mic`, which apps use as their
      # static input. The first stage captures from the current default source, so the
      # `audio-input` switcher just needs to call `wpctl set-default <source>`.
      #
      # Control values are translated from the EasyEffects "mic-input" preset (see
      # modules/packages/easyeffects/easyeffects.nix). Symbols are LSP LV2 port codes;
      # thresholds/gains are linear (e.g. 0.00316 ≈ -50 dB, 0.1 ≈ -20 dB), times in ms.
      # Verify with `journalctl --user -u pipewire -f` after rebuild — any unknown
      # control logs "control ... can not be set".
      micVirtualSource = "source-mic";

      # One LV2 plugin per filter-chain. The capture side is a stream that targets a
      # source (the previous stage, or the default source for the first stage); the
      # playback side is published as an Audio/Source so the next stage can target it.
      mkMicFilter = { mediaName, description, sourceTarget, outNode, outDescription, uri, control ? { } }: {
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
            "node.name" = "${mediaName}-cap";
            "audio.position" = [ "MONO" ];
            # Stream-style capture from a source.
            "stream.capture.sink" = false;
          } // lib.optionalAttrs (sourceTarget != "") {
            "node.target" = sourceTarget;
          };
          "playback.props" = {
            "node.name" = outNode;
            "node.description" = outDescription;
            "media.class" = "Audio/Source";
            "audio.position" = [ "MONO" ];
            # Keep intermediate sources out of default-source selection.
            "priority.session" = 100;
            "priority.driver" = 100;
          };
        };
      };

      # Stage 1: noise gate (LSP gate_mono). EasyEffects preset: threshold -50 dB,
      # reduction -15 dB, attack 1 ms, release 200 ms, hysteresis -3 dB.
      micGateControl = {
        "enabled" = 1.0;
        "gt" = 0.00316;  # curve threshold ≈ -50 dB
        "gz" = 0.7943;   # curve zone ≈ -2 dB
        "ht" = 0.7079;   # hysteresis threshold ≈ -3 dB
        "hz" = 0.8913;   # hysteresis zone ≈ -1 dB
        "gr" = 0.1778;   # gain reduction ≈ -15 dB
        "at" = 1.0;      # attack (ms)
        "rt" = 200.0;    # release (ms)
        "mk" = 1.0;      # makeup (linear)
      };

      # Stage 2: 5-band parametric EQ (LSP para_equalizer_x16_mono).
      # Bands (matching EasyEffects):
      #   0  Hi-pass    50 Hz   gain  +3 dB   Q 0.7
      #   1  Lo-shelf   90 Hz   gain  +3 dB   Q 0.7
      #   2  Bell      425 Hz   gain  -2 dB   Q 1.0
      #   3  Bell     3500 Hz   gain  +3 dB   Q 0.7
      #   4  Hi-shelf 9000 Hz   gain  +2 dB   Q 0.7
      # LSP para_equalizer LV2 ports use the pattern <code>_<band>: ft_X (filter type),
      # fm_X (slope), f_X (freq), g_X (gain, linear), q_X (Q), xs_X (band enabled).
      # ftype enum (LSP): 0=Off, 1=Bell, 2=Hi-pass, 3=Hi-shelf, 4=Lo-pass, 5=Lo-shelf,
      # 6=Notch, 7=Resonance, 8=Ladder-pass, 9=Ladder-rej, 10=Allpass.
      micEqControl = {
        "enabled" = 1.0;
        "mode" = 0.0;        # IIR
        "bal" = 0.0;
        # Band 0: Hi-pass 50 Hz
        "xs_0" = 1.0; "ft_0" = 2.0; "f_0" = 50.0;   "g_0" = 1.0;    "q_0" = 0.7;
        # Band 1: Lo-shelf 90 Hz +3 dB
        "xs_1" = 1.0; "ft_1" = 5.0; "f_1" = 90.0;   "g_1" = 1.4125; "q_1" = 0.7;
        # Band 2: Bell 425 Hz -2 dB
        "xs_2" = 1.0; "ft_2" = 1.0; "f_2" = 425.0;  "g_2" = 0.7943; "q_2" = 1.0;
        # Band 3: Bell 3.5 kHz +3 dB
        "xs_3" = 1.0; "ft_3" = 1.0; "f_3" = 3500.0; "g_3" = 1.4125; "q_3" = 0.7;
        # Band 4: Hi-shelf 9 kHz +2 dB
        "xs_4" = 1.0; "ft_4" = 3.0; "f_4" = 9000.0; "g_4" = 1.2589; "q_4" = 0.7;
      };

      # Stage 3: compressor (LSP compressor_mono). EasyEffects preset: 4:1 ratio,
      # threshold -20 dB, attack 5 ms, release 75 ms, soft knee -6 dB, downward mode.
      micCompressorControl = {
        "enabled" = 1.0;
        "cm" = 0.0;
        "al" = 0.1;      # threshold ≈ -20 dB
        "cr" = 4.0;
        "at" = 5.0;
        "rt" = 75.0;
        "kn" = 0.5;      # knee ≈ -6 dB
        "mk" = 1.0;
      };

      micStages = [
        { name = "gate"; uri = "http://lsp-plug.in/plugins/lv2/gate_mono";               control = micGateControl;       description = "Mic: gate"; }
        { name = "eq";   uri = "http://lsp-plug.in/plugins/lv2/para_equalizer_x16_mono"; control = micEqControl;         description = "Mic: EQ"; }
        { name = "comp"; uri = "http://lsp-plug.in/plugins/lv2/compressor_mono";         control = micCompressorControl; description = "Mic: compressor"; }
      ];

      micStageNode = i: stage:
        if i == (lib.length micStages - 1) then micVirtualSource
        else "source-mic-${stage.name}";

      micChain = lib.imap0
        (i: stage:
          let
            prev = if i == 0 then "" else "source-mic-${(lib.elemAt micStages (i - 1)).name}";
            outNode = micStageNode i stage;
            outDescription =
              if i == (lib.length micStages - 1) then "Mic (effects)"
              else stage.description;
          in
          mkMicFilter {
            mediaName = "mic-${stage.name}";
            inherit (stage) description uri control;
            sourceTarget = prev;
            inherit outNode outDescription;
          })
        micStages;

      # ── Input switcher ───────────────────────────────────────────────────────
      # List physical sources (alsa_input/bluez_input) and let the user pick one as
      # the default source. The first stage of the mic chain captures from the
      # default source, so this redirects the chain without any other plumbing.
      audioInputScript = pkgs.writeShellApplication {
        name = "audio-input";
        runtimeInputs = [ pkgs.jq pkgs.wofi pkgs.pipewire pkgs.wireplumber pkgs.libnotify ];
        text = ''
          mapfile -t entries < <(pw-dump | jq -r '
            .[] | select(.type=="PipeWire:Interface:Node")
                | select(.info.props."media.class"=="Audio/Source")
                | select(.info.props."node.name" | test("^(alsa_input|bluez_input)"))
                | "\(.id)\t\(.info.props."node.description" // .info.props."node.name")"')

          if [ "''${#entries[@]}" -eq 0 ]; then
            notify-send "Audio input" "No physical input devices found"
            exit 1
          fi

          choice=$(printf '%s\n' "''${entries[@]}" | cut -f2- | wofi --dmenu -p "Input device") || exit 0
          [ -n "$choice" ] || exit 0
          id=$(printf '%s\n' "''${entries[@]}" | awk -F'\t' -v d="$choice" '$2==d{print $1; exit}')
          [ -n "$id" ] || exit 1

          wpctl set-default "$id"
          notify-send "Audio input" "→ $choice"
        '';
      };

      # ── Combined input+output switcher ───────────────────────────────────────
      # Pair sinks and sources by node-name suffix (strip alsa_(input|output). or
      # bluez_(input|output). prefix) so both ends switch in one menu pick. Useful
      # when a device exposes both ends (Scarlett, USB headsets, BT headsets).
      audioDeviceScript = pkgs.writeShellApplication {
        name = "audio-device";
        runtimeInputs = [ pkgs.jq pkgs.wofi pkgs.pipewire pkgs.wireplumber pkgs.libnotify ];
        text = ''
          # Emit "kind<TAB>suffix<TAB>id<TAB>description" for every physical node.
          mapfile -t rows < <(pw-dump | jq -r '
            .[] | select(.type=="PipeWire:Interface:Node")
                | select(.info.props."media.class"=="Audio/Sink" or .info.props."media.class"=="Audio/Source")
                | select(.info.props."node.name" | test("^(alsa|bluez)_(input|output)\\."))
                | (if .info.props."media.class"=="Audio/Sink" then "sink" else "source" end) as $kind
                | (.info.props."node.name" | sub("^(alsa|bluez)_(input|output)\\."; "")) as $suffix
                | "\($kind)\t\($suffix)\t\(.id)\t\(.info.props."node.description" // .info.props."node.name")"')

          declare -A sink_id sink_desc source_id source_desc
          declare -A seen_suffix

          for row in "''${rows[@]}"; do
            IFS=$'\t' read -r kind suffix id desc <<< "$row"
            if [ "$kind" = "sink" ]; then
              sink_id[$suffix]=$id
              sink_desc[$suffix]=$desc
            else
              source_id[$suffix]=$id
              source_desc[$suffix]=$desc
            fi
            seen_suffix[$suffix]=1
          done

          # Build menu of suffixes that have BOTH a sink and a source.
          declare -A menu_to_suffix
          menu_lines=()
          for suffix in "''${!seen_suffix[@]}"; do
            if [ -n "''${sink_id[$suffix]:-}" ] && [ -n "''${source_id[$suffix]:-}" ]; then
              label="''${sink_desc[$suffix]}"
              if [ "''${sink_desc[$suffix]}" != "''${source_desc[$suffix]}" ]; then
                label="''${sink_desc[$suffix]} / ''${source_desc[$suffix]}"
              fi
              menu_to_suffix[$label]=$suffix
              menu_lines+=("$label")
            fi
          done

          if [ "''${#menu_lines[@]}" -eq 0 ]; then
            notify-send "Audio device" "No paired sink+source devices found"
            exit 1
          fi

          choice=$(printf '%s\n' "''${menu_lines[@]}" | wofi --dmenu -p "Audio device") || exit 0
          [ -n "$choice" ] || exit 0
          suffix=''${menu_to_suffix[$choice]:-}
          [ -n "$suffix" ] || exit 1

          wpctl set-default "''${sink_id[$suffix]}"
          wpctl set-default "''${source_id[$suffix]}"
          notify-send "Audio device" "→ $choice"
        '';
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
