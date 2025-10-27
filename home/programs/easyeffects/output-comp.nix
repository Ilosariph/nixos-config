
{
  services.easyeffects.extraPresets = {
	output-comp = {
    "output" = {
        "blocklist" = [];
        "compressor#0" = {
            "attack" = 20.0;
            "boost-amount" = 6.0;
            "boost-threshold" = -72.0;
            "bypass" = false;
            "dry" = -100.0;
            "hpf-frequency" = 10.0;
            "hpf-mode" = "off";
            "input-gain" = 0.0;
            "knee" = -6.0;
            "lpf-frequency" = 20000.0;
            "lpf-mode" = "off";
            "makeup" = -6.938893903907228e-16;
            "mode" = "Downward";
            "output-gain" = 0.0;
            "ratio" = 4.0;
            "release" = 100.0;
            "release-threshold" = -100.0;
            "sidechain" = {
                "lookahead" = 0.0;
                "mode" = "RMS";
                "preamp" = 0.0;
                "reactivity" = 10.0;
                "source" = "Middle";
                "stereo-split-source" = "Left/Right";
                "type" = "Feed-forward";
            };
            "stereo-split" = false;
            "threshold" = -12.0;
            "wet" = 0.0;
        };
        "compressor#1" = {
            "attack" = 20.0;
            "boost-amount" = 6.0;
            "boost-threshold" = -65.0;
            "bypass" = false;
            "dry" = -100.0;
            "hpf-frequency" = 10.0;
            "hpf-mode" = "off";
            "input-gain" = 0.0;
            "knee" = -6.0;
            "lpf-frequency" = 20000.0;
            "lpf-mode" = "off";
            "makeup" = 0.0;
            "mode" = "Upward";
            "output-gain" = 0.0;
            "ratio" = 3.4999999999999893;
            "release" = 100.0;
            "release-threshold" = -100.0;
            "sidechain" = {
                "lookahead" = 0.0;
                "mode" = "RMS";
                "preamp" = 0.0;
                "reactivity" = 10.0;
                "source" = "Middle";
                "stereo-split-source" = "Left/Right";
                "type" = "Feed-forward";
            };
            "stereo-split" = false;
            "threshold" = -12.0;
            "wet" = 0.0;
        };
        "limiter#0" = {
            "alr" = false;
            "alr-attack" = 5.0;
            "alr-knee" = 0.0;
            "alr-release" = 50.0;
            "attack" = 5.0;
            "bypass" = false;
            "dithering" = "None";
            "external-sidechain" = false;
            "gain-boost" = true;
            "input-gain" = 0.0;
            "lookahead" = 5.0;
            "mode" = "Herm Thin";
            "output-gain" = 0.0;
            "oversampling" = "None";
            "release" = 5.0;
            "sidechain-preamp" = 0.0;
            "stereo-link" = 100.0;
            "threshold" = 0.0;
        };
        "plugins_order" = [
            "compressor#1"
            "compressor#0"
            "limiter#0"
        ];
    };
  };
};
}
