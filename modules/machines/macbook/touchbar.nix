{ pkgs, inputs, config, ... }:
let
  dfrdPkg = inputs.dfrd.packages.${pkgs.system}.default;

  # Workaround for a flaky boot-time race in the apple-z2 kernel driver
  # (the touch bar controller): it sometimes fails to probe on boot with
  # `apple-z2 spi0.0: probe with driver apple-z2 failed with error -110`
  # (ETIMEDOUT). When that happens the "Touch Bar" input device never
  # appears, the udev rule that triggers tiny-dfr.service never fires,
  # and the touch bar just stays blank — dfrd/tiny-dfr itself is fine,
  # it's simply never started. Forcing a driver rebind reprobes the
  # device and reliably brings the touch bar up without a reboot.
  touchbarFix = pkgs.writeShellScriptBin "touchbar-fix" ''
    echo spi0.0 | sudo tee /sys/bus/spi/drivers/apple-z2/bind
  '';
in
{
  environment.systemPackages = [ touchbarFix ];

  hardware.apple.touchBar = {
    enable = true;
    package = dfrdPkg;
    settings = {
      ShowButtonOutlines = true;
      EnablePixelShift = true;
      FontTemplate = ":bold";
      AdaptiveBrightness = true;
      ActiveBrightness = 128;
      DefaultLayer = "Primary";
      FnOverlayLayer = "Media";

      Layers = [
        {
          Name = "Primary";
          Keys = [
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
        }
        {
          Name = "Media";
          Keys = [
            { Icon = "brightness_low";  Action = "BrightnessDown"; }
            { Icon = "brightness_high"; Action = "BrightnessUp";   }
            { Icon = "volume_down";     Action = "VolumeDown";     }
            { Icon = "volume_up";       Action = "VolumeUp";       }
            { Icon = "mic_off";         Action = "MicMute";        }

            {
              Icon = "clock";
              Time = "%H:%M %-e.%m.%Y";
              Action = "Time";
              Stretch = 3;
            }

            { Icon = "fast_rewind";    Action = "PreviousSong"; }
            { Icon = "play_pause";     Action = "PlayPause";    }
            { Icon = "fast_forward";   Action = "NextSong";     }
            # { Icon = "backlight_low";  Action = "IllumDown";    }
            # { Icon = "backlight_high"; Action = "IllumUp";      }

            { Battery = "percentage"; Action = "Battery"; }
            { Icon = "layers"; Text = "Apps"; Action = { SwitchLayer = "Apps"; }; }
          ];
        }
        {
          Name = "Apps";
          Keys = [
            { Text = "Firefox"; Action = { Exec = "firefox"; }; }
            { Text = "Term";    Action = { Exec = "kitty"; }; }
            { Text = "Yazi";    Action = { Exec = "kitty -e yazi"; }; }
          ];
        }
      ];
    };
  };

  # Companion agent: dfrd (the root daemon above) is sandboxed and
  # privilege-dropped to `nobody`, so it can't itself run shell
  # commands/launch apps with a real desktop session. This runs in the
  # actual login session (same pattern as the existing hyprpolkitagent
  # service in modules/packages/waybar/waybar.nix) and executes Exec
  # actions forwarded from dfrd over /run/tiny-dfr/agent.sock.
  home-manager.users.${config.dotfiles.user.name}.systemd.user.services.dfrd-agent = {
    Unit = {
      Description = "dfrd companion agent (user-session action executor)";
      PartOf = [ "graphical-session.target" ];
      After = [ "graphical-session.target" ];
    };
    Service = {
      ExecStart = "${dfrdPkg}/bin/dfrd-agent";
      Restart = "on-failure";
      RestartSec = 2;
    };
    Install.WantedBy = [ "graphical-session.target" ];
  };
}
