{ ... }: {
  # Wofi launcher/menu styling. Kept independent of the statusbar so it applies to every
  # desktop and to all wofi callers — the app launcher *and* the audio-output device
  # switcher (see audio-routing.nix) — not just waybar setups.
  flake.nixosModules.wofi = { config, lib, pkgs, ... }:
    lib.mkIf config.dotfiles.desktop.enable {
      home-manager.users.${config.dotfiles.user.name} = { pkgs, ... }: {
        home.packages = [ pkgs.wofi ];

        xdg.configFile."wofi/config".source = ./config;

        xdg.configFile."wofi/style.css".source = ./style.css;
      };
    };
}
