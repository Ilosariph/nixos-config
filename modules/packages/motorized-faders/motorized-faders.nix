{ inputs, ... }: {
  flake.nixosModules.motorized-faders = { config, lib, ... }: {
    imports = [ inputs.motorized-faders.nixosModules.default ];

    config = lib.mkIf config.dotfiles.programs.motorizedFaders.enable {
      services.motorized-faders = {
        enable = true;
        # Sinks come from dotfiles.audio.sinks (audio-routing names them
        # sink-<name>); max > 100 lets a fader boost past unity.
        plugins.pulse_sink = [
          { fader = 0; sink = "sink-master"; min = 0; max = 100; label = "Master"; }
          { fader = 1; sink = "sink-apps"; min = 0; max = 150; label = "Apps"; }
          { fader = 2; sink = "sink-comms"; min = 0; max = 150; label = "Comms"; }
          { fader = 3; sink = "sink-music"; min = 0; max = 150; label = "Music"; }
        ];
      };
    };
  };
}
