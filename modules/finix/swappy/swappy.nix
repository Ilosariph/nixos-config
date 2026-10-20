{ ... }: {
  flake.finixModules.swappy = { config, lib, pkgs, ... }:
    lib.mkIf config.dotfiles.desktop.enable {
      environment.systemPackages = [
        pkgs.swappy
        # Region screenshot on a frozen screen (same as the NixOS aspect).
        # Extra args go to slurp, e.g. `screenshot-region -o` to pick an output.
        (pkgs.writeShellApplication {
          name = "screenshot-region";
          runtimeInputs = with pkgs; [ wayfreeze slurp grim swappy ];
          text = ''
            wayfreeze --hide-cursor &
            freeze=$!
            img=$(mktemp --suffix=.png)
            trap 'kill "$freeze" 2>/dev/null || true; rm -f "$img"' EXIT
            sleep 0.1
            geom=$(slurp "$@") || exit 0
            grim -g "$geom" "$img"
            kill "$freeze" 2>/dev/null || true
            swappy -f "$img"
          '';
        })
      ];

      hjem.users.${config.dotfiles.user.name}.xdg.config.files."swappy/config".text = ''
        [Default]
        auto_save=false
        early_exit=true
        save_dir=$HOME/Pictures/Screenshots/
        show_panel=true
      '';
    };
}
