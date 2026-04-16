{ ... }: {
  flake.nixosModules.direnv = { config, lib, pkgs, ... }:
    let
      shells = config.dotfiles.direnv.shells;
    in
    lib.mkIf (shells != []) {
      home-manager.users.${config.dotfiles.user.name} = { ... }: {
        programs.direnv = {
          enable = true;
          nix-direnv.enable = true;
        };

        home.file = lib.listToAttrs (map (shell:
          lib.nameValuePair "${shell.dir}/.envrc" {
            text = ''
              if output=$(use nix ${
                if shell.shellFile != null then shell.shellFile
                else pkgs.writeText "shell.nix" ''
                  with import <nixpkgs> {};
                  mkShell {
                    buildInputs = [ ${lib.concatStringsSep " " (map toString shell.packages)} ];
                  }
                ''
              } 2>&1); then
                log_status "devenv ${shell.dir} loaded successfully"
              else
                echo "$output" >&2
                false
              fi
            '';
          }
        ) shells);
      };
    };
}
