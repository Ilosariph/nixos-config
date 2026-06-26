{ ... }: {
  # Wofi launcher/menu styling. Kept independent of the statusbar so it applies to every
  # desktop and to all wofi callers — the app launcher *and* the audio-output device
  # switcher (see audio-routing.nix) — not just waybar setups.
  flake.nixosModules.wofi = { config, lib, pkgs, ... }:
    lib.mkIf config.dotfiles.desktop.enable {
      home-manager.users.${config.dotfiles.user.name} = { pkgs, ... }: {
        home.packages = [ pkgs.wofi ];

        xdg.configFile."wofi/config".text = ''
          width=620
          height=420
          location=center
          show=drun
          prompt=Search...
          filter_rate=100
          allow_markup=true
          no_actions=true
          halign=fill
          orientation=vertical
          content_halign=fill
          insensitive=true
          allow_images=true
          image_size=36
          gtk_dark=true
          term=kitty
        '';

        xdg.configFile."wofi/style.css".text = ''
          /* ── Tokyo Night palette ─────────────────────────────────────────── */
          @define-color background  #1a1b26;
          @define-color surface     #24283b;
          @define-color overlay     #2a2b3d;
          @define-color muted       #595959;
          @define-color subtle      #414868;
          @define-color text        #a9b1d6;
          @define-color text-bright #c0caf5;
          @define-color accent-blue #33ccff;
          @define-color accent-green #00ff99;

          * {
            font-family: JetBrainsMono Nerd Font, JetBrains Mono, monospace;
            font-size: 14px;
            color: @text;
          }

          window { background: transparent; }

          #window {
            background-color: @background;
            border-radius: 12px;
            border: 2px solid @accent-blue;
            box-shadow: 0 8px 32px alpha(#000000, 0.6);
          }

          #outer-box {
            background-color: transparent;
            padding: 12px;
            border-radius: 12px;
          }

          #input {
            background-color: @surface;
            color: @text-bright;
            border: 1px solid @subtle;
            border-radius: 8px;
            padding: 8px 12px;
            margin-bottom: 8px;
            caret-color: @accent-blue;
            outline: none;
          }

          #input:focus {
            border-color: @accent-blue;
            box-shadow: 0 0 0 1px alpha(@accent-blue, 0.4);
          }

          #scroll { background-color: transparent; border: none; margin: 0; padding: 0; }
          #inner-box { background-color: transparent; }

          #entry {
            background-color: transparent;
            border-radius: 8px;
            padding: 6px 10px;
            margin: 2px 0;
            transition: background-color 100ms ease;
          }

          #entry:hover { background-color: @overlay; }

          #entry:selected {
            background-color: @overlay;
            border-left: 2px solid @accent-blue;
          }

          #entry:selected #text { color: @text-bright; }

          #text { color: @text; margin-left: 6px; }
          #img { margin-right: 4px; border-radius: 4px; }
        '';
      };
    };
}
