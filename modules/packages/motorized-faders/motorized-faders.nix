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
        # Sinks come from dotfiles.audio.sinks (audio-routing names them
        # sink-<name>); max > 100 lets a fader boost past unity.
        plugins.pulse_sink = [
          { fader = 0; sink = "sink-music"; min = 0; max = 150; label = "Music"; }
          { fader = 1; sink = "sink-comms"; min = 0; max = 150; label = "Comms"; }
          { fader = 2; sink = "sink-apps"; min = 0; max = 150; label = "Apps"; }
          { fader = 3; sink = "sink-master"; min = 0; max = 100; label = "Master"; }
        ];
        # Client ID from private.nix; the client secret stays out of the
        # world-readable store, in a file only this user reads.
        plugins.discord_voice = {
          client_id = config.dotfiles.private.motorizedFaders.discordClientId;
          client_secret_file = "~/.config/motorized-faders/discord-secret";
          max_volume = 200;
        };
        # URL from private.nix. Faders fill in order; more than four page
        # with G2 + F1/F4, null leaves a fader empty.
        plugins.home_assistant = {
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
      };
    };
  };
}
