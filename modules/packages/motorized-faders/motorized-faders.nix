{ inputs, ... }: {
  flake.nixosModules.motorized-faders = { config, lib, ... }: {
    imports = [ inputs.motorized-faders.nixosModules.default ];

    config = lib.mkIf config.dotfiles.programs.motorizedFaders.enable {
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
      };
    };
  };
}
