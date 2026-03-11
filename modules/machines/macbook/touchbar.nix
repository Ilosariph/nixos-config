{ pkgs, ... }:
{
  hardware.apple.touchBar = {
    enable = true;
    package = pkgs.tiny-dfr;
		settings = {
			MediaLayerDefault = false;
			ShowButtonOutlines = true;
			EnablePixelShift = true;
			FontTemplate = ":bold";
			AdaptiveBrightness = true;
			ActiveBrightness = 128;

			PrimaryLayerKeys = [
				{ Text = "F1";  Action = "F1";  }
				{ Text = "F2";  Action = "F2";  }
				{ Text = "F3";  Action = "F3";  }
				{ Text = "F4";  Action = "F4";  }
				{ Text = "F5";  Action = "F5";  }
				{ Text = "F6";  Action = "F6";  }
				{ Text = "F7";  Action = "F7";  }
				{ Text = "F8";  Action = "F8";  }
				{ Text = "F9";  Action = "F9";  }
				{ Text = "F10"; Action = "F10"; }
				{ Text = "F11"; Action = "F11"; }
				{ Text = "F12"; Action = "F12"; }
			];

			MediaLayerKeys = [
				{ Icon = "brightness_low";  Action = "BrightnessDown"; }
				{ Icon = "brightness_high"; Action = "BrightnessUp";   }
				{ Icon = "volume_down";     Action = "VolumeDown";     }
				{ Icon = "volume_up";       Action = "VolumeUp";       }
				{ Icon = "mic_off";         Action = "MicMute";        }

				{
					Time = "%H:%M %-e.%m.%Y";
					Action = "Time";
					Stretch = 2;
				}

				{ Icon = "fast_rewind";    Action = "PreviousSong"; }
				{ Icon = "play_pause";     Action = "PlayPause";    }
				{ Icon = "fast_forward";   Action = "NextSong";     }
				{ Icon = "backlight_low";  Action = "IllumDown";    }
				{ Icon = "backlight_high"; Action = "IllumUp";      }

				# { Battery = "percentage"; Action = "Battery"; }
			];
		};
  };
}
