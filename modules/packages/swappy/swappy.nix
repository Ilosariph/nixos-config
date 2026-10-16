{ ... }: {
  flake.nixosModules.swappy = { config, lib, pkgs, ... }:
    lib.mkIf config.dotfiles.desktop.enable {
      home-manager.users.${config.dotfiles.user.name} = { ... }: {
        programs.swappy.enable = true;
        programs.swappy.settings = {
          Default = {
            auto_save = false;
            save_dir = "$HOME/Pictures/Screenshots/";
            show_panel = true;
            early_exit = true;
          };
        };

        # Region screenshot on a frozen screen (videos/animations stop while selecting).
        # Extra args go to slurp, e.g. `screenshot-region -o` to pick an output.
        home.packages = [
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
      };
    };
}
