{ ... }: {
  # finix counterpart of modules/packages/audio-routing (+ mic-mute). The
  # routing building blocks come from modules/packages/audio-routing/_audio.nix;
  # here they become pipewire conf.d drop-ins (programs.pipewire.packages) and
  # wireplumber settings. finit has no user services, so `start-audio-daemons`
  # (run from the compositor autostart) launches pipewire, pipewire-pulse and
  # wireplumber for the session.
  flake.finixModules.audio = { config, lib, pkgs, ... }:
    let
      cfg = config.dotfiles.audio;
      audio = import ../../packages/audio-routing/_audio.nix { inherit lib pkgs cfg; };
      isVirtual = cfg.routing == "pipewire-virtual";
      needsLv2 = isVirtual && (audio.anyEffects || cfg.micEffects.enable);

      json = pkgs.formats.json { };
      dropIn = location: name: settings:
        pkgs.runCommand "pipewire-${name}" { } ''
          mkdir -p $out/share/pipewire/${location}.conf.d
          cp ${json.generate "${name}.conf" settings} $out/share/pipewire/${location}.conf.d/${name}.conf
        '';

      pipewire = config.programs.pipewire.package;
      wireplumber = config.programs.wireplumber.package;

      startAudioDaemons = pkgs.writeShellApplication {
        name = "start-audio-daemons";
        runtimeInputs = [ pkgs.coreutils pkgs.procps ];
        text = ''
          # Session-scoped audio stack (NixOS: pipewire/wireplumber systemd user units)
          ${lib.optionalString needsLv2 ''export LV2_PATH="${pkgs.lsp-plugins}/lib/lv2"''}
          pkill -u "$(id -u)" -x pipewire || true
          pkill -u "$(id -u)" -x pipewire-pulse || true
          pkill -u "$(id -u)" -x wireplumber || true

          ${pipewire}/bin/pipewire &
          until [ -S "$XDG_RUNTIME_DIR/pipewire-0" ]; do sleep 0.1; done
          ${pipewire}/bin/pipewire-pulse &
          ${wireplumber}/bin/wireplumber &
          wait
        '';
      };

      micMuteScript = pkgs.writeShellApplication {
        name = "mic-mute";
        runtimeInputs = [ pkgs.wireplumber pkgs.libnotify ];
        text = builtins.readFile ../../packages/mic-mute/mic-mute.sh;
      };
    in
    lib.mkIf config.dotfiles.desktop.enable (lib.mkMerge [
      {
        environment.systemPackages = [ startAudioDaemons micMuteScript ];
      }

      (lib.mkIf (cfg.routing == "pulsemeeter") {
        dotfiles.audio.easyeffects.enable = lib.mkDefault true;
        environment.systemPackages = with pkgs; [ pulsemeeter qpwgraph ];
      })

      (lib.mkIf isVirtual {
        dotfiles.audio.micEffects.enable = lib.mkDefault true;

        environment.systemPackages = [
          pkgs.qpwgraph
          audio.audioOutputScript
          audio.audioInputScript
          audio.audioDeviceScript
        ];

        programs.pipewire.packages = [
          (dropIn "pipewire" "10-virtual-sinks" {
            "context.objects" =
              (map audio.mkNullSink cfg.sinks)
              ++ lib.optional (cfg.sinks != [ ]) audio.masterNullSink;
            "context.modules" =
              (map audio.mkLoopback cfg.sinks)
              ++ lib.optional (cfg.sinks != [ ]) audio.masterLoopback
              ++ lib.concatMap audio.mkEffectsChain audio.effectsSinks;
          })
          (dropIn "pipewire-pulse" "10-volume-limit" {
            "stream.properties"."volume.limit" = cfg.volumeLimit;
          })
          (dropIn "pipewire-pulse" "20-app-routing" {
            "pulse.rules" = audio.pulseRules;
          })
        ] ++ lib.optional cfg.micEffects.enable (dropIn "pipewire" "20-mic-chain" {
          "context.modules" = audio.micChain;
        });

        programs.wireplumber.settings."monitor.alsa.rules" =
          lib.optional (cfg.outputSink != "") {
            matches = [ { "node.name" = cfg.outputSink; } ];
            actions.update-props = {
              "priority.session" = 2000;
              "priority.driver" = 2000;
            };
          }
          ++ lib.optional (cfg.inputSource != "") {
            matches = [ { "node.name" = cfg.inputSource; } ];
            actions.update-props = {
              "priority.session" = 2000;
              "priority.driver" = 2000;
            };
          };
      })
    ]);
}
