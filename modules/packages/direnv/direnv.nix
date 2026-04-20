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

        home.file = lib.foldl' (acc: shell:
          acc //
          {
            "${shell.dir}/.envrc".text = ''
              use nix && log_status "devenv ${shell.dir} loaded successfully"
            '';
          } //
          (if shell.shellFile != null then {
            "${shell.dir}/shell.nix".source = shell.shellFile;
          } else {
            "${shell.dir}/shell.nix".text = ''
              with import <nixpkgs> {};
              mkShell {
                buildInputs = [ ${lib.concatStringsSep " " (map toString shell.packages)} ];
              }
            '';
          })
        ) {} shells;
      };
    };
}
