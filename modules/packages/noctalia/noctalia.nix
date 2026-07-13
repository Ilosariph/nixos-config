{ inputs, ... }: {
  flake.nixosModules.noctalia = { config, lib, ... }:
    lib.mkIf (config.dotfiles.desktop.enable && config.dotfiles.windowManager.statusbar == "noctalia") {
      home-manager.sharedModules = [ inputs.noctalia-shell.homeModules.default ];
      home-manager.users.${config.dotfiles.user.name} = { lib, pkgs, config, osConfig, ... }:
        let
          wmCfg = osConfig.dotfiles.windowManager;
          monName = s: lib.trim (builtins.head (lib.splitString "," s));
          monNames = map monName wmCfg.settings.monitors;
          mainMon =
            if wmCfg.mainMonitor != "" then wmCfg.mainMonitor
            else if monNames != [] then builtins.head monNames
            else "";
          loginBoxSettings = {
            background_color = "surface_variant";
            background_opacity = 0.88;
            background_radius = 12.0;
            input_opacity = 1.0;
            input_radius = 6.0;
            show_caps_lock = true;
            show_keyboard_layout = true;
            show_login_button = true;
            show_password_hint = true;
          };
          loginBox = { output, cx, cy }: {
            box_height = 70.0;
            box_width = 400.0;
            inherit cx cy output;
            rotation = 0.0;
            type = "login_box";
            settings = loginBoxSettings;
          };
          lockWidgetName = m: "lockscreen-login-box@${m}";
          lockWidgets = {
            ${lockWidgetName mainMon} = loginBox { output = mainMon; cx = 1720.0; cy = 1321.0; };
          };
          wallpaperStore = pkgs.runCommand "wallpapers" { } ''
            mkdir -p $out
            cp -r ${osConfig.dotfiles.wallpapers.directory}/. $out/
          '';
          randomWallpaperScript = pkgs.writeShellScript "noctalia-random-wallpaper" ''
            set -eu
            for _ in $(seq 1 30); do
              if ${inputs.noctalia-shell.packages.${pkgs.system}.default}/bin/noctalia msg wallpaper-random >/dev/null 2>&1; then
                exit 0
              fi
              sleep 1
            done
            exit 1
          '';
        in {
          programs.noctalia = {
            enable = true;
            systemd.enable = true;
            settings = {
              config_version = 2;

              wallpaper = {
                enabled = true;
                fill_mode = "crop";
                directory = "${wallpaperStore}";
              };

              bar.main = {
                center = [ "workspaces" ];
                end = [ "tray" "notifications" "network" "battery" "control-center" ];
                margin_ends = 0;
                radius = 0;
                start = [ "launcher" "group:g2" "group:g1" "media" ];
                widget_spacing = 12;
                capsule_group = [
                  {
                    enabled = true;
                    fill = "outline";
                    id = "g1";
                    members = [ "cpu" "temp" "ram" ];
                    opacity = 1.0;
                    padding = 6.0;
                  }
                  {
                    enabled = true;
                    fill = "outline";
                    id = "g2";
                    members = [ "clock" "date" ];
                    opacity = 1.0;
                    padding = 6.0;
                  }
                ];
              };

              control_center = {
                hidden_tabs = [ "power" "screen-time" ];
                shortcuts = [
                  { type = "wifi"; }
                  { type = "bluetooth"; }
                  { type = "power_profile"; }
                ];
              };

              lockscreen_widgets = {
                enabled = false;
                schema_version = 2;
                widget_order = [ (lockWidgetName mainMon) ];
                grid = {
                  cell_size = 16;
                  major_interval = 4;
                  visible = true;
                };
                widget = lockWidgets;
              };

              notification.monitors = [ mainMon ];
              osd.monitors = [ mainMon ];

              shell = {
                password_style = "random";
                polkit_agent = true;
                telemetry_enabled = true;
                launcher = {
                  categories = false;
                  compact = true;
                  show_icons = false;
                };
                panel = {
                  control_center_placement = "floating";
                  open_near_click_control_center = true;
                };
              };

              widget = {
                date.format = "{:%a, %d %b}";
                tray = {
                  capsule = true;
                  capsule_fill = "outline";
                };
              };
            };
          };

          systemd.user.services.noctalia-random-wallpaper = {
            Unit = {
              Description = "Pick a random Noctalia wallpaper on session start";
              After = [ "graphical-session.target" ];
              PartOf = [ "graphical-session.target" ];
            };
            Service = {
              Type = "oneshot";
              ExecStart = "${randomWallpaperScript}";
            };
            Install.WantedBy = [ "graphical-session.target" ];
          };
        };
    };
}
