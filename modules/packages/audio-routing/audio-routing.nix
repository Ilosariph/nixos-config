{ ... }: {
  flake.nixosModules.audio-routing = { config, lib, pkgs, ... }:
    let
      cfg = config.dotfiles.audio;

      mkNullSink = { name, description }: {
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
        };
      };

      # Capture from the monitor of a null sink and play back to the physical output.
      # stream.capture.sink = true connects the capture side to the sink's monitor output.
      mkLoopback = name: {
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
          } // lib.optionalAttrs (cfg.outputSink != "") {
            # Pin to the physical output so this stream is never re-routed to a
            # virtual sink. Required when default.audio.sink points at a null sink.
            "target.object" = cfg.outputSink;
          };
        };
      };

    in
    lib.mkIf config.dotfiles.desktop.enable (lib.mkMerge [

      # EasyEffects is useful in both pulsemeeter and pipewire-virtual modes:
      # it provides the mic processing chain and virtual source for the Scarlett input.
      (lib.mkIf (cfg.routing != "none") {
        dotfiles.audio.easyeffects.enable = lib.mkDefault true;
        environment.systemPackages = [ pkgs.qpwgraph ];
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

        # Three null sinks + loopbacks from each monitor to the physical output.
        # Loopback playback nodes are visible as individual streams in volume mixers
        # (pavucontrol, StreamController) so each virtual sink has its own level.
        services.pipewire.extraConfig.pipewire."10-virtual-sinks" = {
          "context.objects" = [
            (mkNullSink { name = "apps";  description = "Apps";  })
            (mkNullSink { name = "music"; description = "Music"; })
            (mkNullSink { name = "comms"; description = "Comms"; })
          ];
          "context.modules" = [
            (mkLoopback "apps")
            (mkLoopback "music")
            (mkLoopback "comms")
          ];
        };

        services.pipewire.wireplumber.extraConfig."10-virtual-routing" = {
          # Make the apps sink the default so new streams land there unless redirected.
          "wireplumber.settings"."default.audio.sink" = "sink-apps";

          # Redirect specific applications to their designated sinks.
          # Add further entries here to route additional programs.
          # target.object must match node.name of the null sink above.
          "wireplumber.rules" = [
            {
              matches = [
                # Spotify uses both these identifiers depending on the version/launch method.
                { "application.process.binary" = "spotify"; }
                { "application.name" = "Spotify"; }
              ];
              actions.update-props."target.object" = "sink-music";
            }
            {
              matches = [
                { "application.process.binary" = "audacity"; }
              ];
              actions.update-props."target.object" = "sink-music";
            }
            # Pin EasyEffects' output stream to the physical Scarlett sink so it
            # doesn't follow the default (sink-apps) and create a feedback loop.
            {
              matches = [
                { "node.name" = "ee_soe_output_level"; }
              ];
              actions.update-props."target.object" = cfg.outputSink;
            }
            # Discord and games select the comms sink directly in their settings;
            # no rule needed here unless you want to force it.
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
