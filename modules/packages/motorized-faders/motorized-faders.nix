{ inputs, ... }: {
  flake.nixosModules.motorized-faders = { config, lib, ... }: {
    imports = [ inputs.motorized-faders.nixosModules.default ];

    config = lib.mkIf config.dotfiles.programs.motorizedFaders.enable {
      # Long-lived HA access token; readable by the user the service runs as.
      sops.secrets.motorized-faders-ha-token = {
        owner = config.dotfiles.user.name;
        mode = "0400";
      };

      services.motorized-faders = {
        enable = true;
        # Explicit layers fix the G1 + F1/F4 order (Audio first, active on
        # start); without them plugins would sort alphabetically.
        layers = [
          {
            name = "Audio";
            # Sinks come from dotfiles.audio.sinks (audio-routing names them
            # sink-<name>); max > 100 lets a fader boost past unity. Faders
            # 4+ are page 2 (hold G2 + F1/F4); tap G2 + Fn for A/B.
            extensions.pulse_sink = {
              paging = "auto";
              faders = [
                { fader = 0; sink = "sink-music"; min = 0; max = 150; label = "Music"; }
                { fader = 1; sink = "sink-comms"; min = 0; max = 150; label = "Comms"; }
                { fader = 2; sink = "sink-apps"; min = 0; max = 150; label = "Apps"; }
                { fader = 3; sink = "sink-master"; min = 0; max = 100; label = "Master"; }
                # "Mic (effects)": the mic-effects chain's output source.
                { fader = 4; source = "source-mic"; min = 0; max = 100; label = "Mic"; }
              ];
            };
          }
          {
            name = "FX";
            # Live controls of the audio-routing LSP filter-chains
            # (<filter name>:<LV2 port symbol>). Pages: 1 Apps comp, 2 Comms
            # comp, 3 Mic gate + comp. Button bypasses that plugin; a detent
            # marks the value from audio-routing.nix. Changes persist across
            # PipeWire restarts; `motorized-faders-fx reset` restores the
            # originals.
            extensions.filter_param = {
              faders =
                let
                  # LSP thresholds/gains are linear: scale "db" maps them in dB.
                  comp = filter: name: [
                    { param = "${filter}:al"; scale = "db"; min = -40; max = 0; label = "${name} thr"; }
                    { param = "${filter}:cr"; scale = "log"; min = 1; max = 10; unit = ":1"; label = "${name} ratio"; }
                    { param = "${filter}:mk"; scale = "db"; min = 0; max = 12; label = "${name} gain"; }
                    { param = "${filter}:rt"; scale = "log"; min = 20; max = 1000; unit = " ms"; label = "${name} rel"; }
                  ];
                in
                comp "fx-comp-apps" "Apps"
                ++ comp "fx-comp-comms" "Comms"
                ++ [
                  { param = "mic-gate:gt"; scale = "db"; min = -80; max = -20; label = "Mic gate"; }
                  { param = "mic-comp:al"; scale = "db"; min = -40; max = 0; label = "Mic thr"; }
                  { param = "mic-comp:cr"; scale = "log"; min = 1; max = 10; unit = ":1"; label = "Mic ratio"; }
                  { param = "mic-comp:mk"; scale = "db"; min = 0; max = 12; label = "Mic gain"; }
                ];
            };
          }
          {
            name = "Discord";
            # Client ID from private.nix; the client secret stays out of the
            # world-readable store, in a file only this user reads.
            extensions.discord_voice = {
              client_id = config.dotfiles.private.motorizedFaders.discordClientId;
              client_secret_file = "~/.config/motorized-faders/discord-secret";
              max_volume = 200;
            };
          }
          {
            name = "Home";
            # URL from private.nix. Faders fill in order; more than four page
            # with G2 + F1/F4, null leaves a fader empty.
            extensions.home_assistant = {
              url = config.dotfiles.private.motorizedFaders.homeAssistantUrl;
              token_file = config.sops.secrets.motorized-faders-ha-token.path;
              faders = [
                { entity = "light.spot"; label = "Spot"; }
                { entity = "light.on_off_light_1"; label = "Balken"; }
                { entity = "cover.zigfredsimon_l7"; attribute = "position"; label = "Blinds"; follow = false; }
                { entity = "cover.zigfredsimon_l7"; attribute = "tilt"; label = "Slats"; follow = false; }
                { entity = "switch.3d_drucker_simon_steckdose_2"; label = "3d Drucker"; }
              ];
            };
          }
          {
            name = "Media";
            # Whichever player is playing (Spotify, Plezy, a browser). Fader 1
            # is its own stream volume, buttons F2/F3/F4 previous, play/pause,
            # next. Last in the list: one G1 + F1 back from Audio.
            extensions.media = { };
          }
        ];
      };
    };
  };
}
