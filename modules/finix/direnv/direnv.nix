{ ... }: {
  flake.finixModules.direnv = { config, lib, pkgs, ... }:
    let
      shells = config.dotfiles.direnv.shells;
    in lib.mkIf (shells != []) {
      environment.systemPackages = [ pkgs.direnv ];

      hjem.users.${config.dotfiles.user.name} = {
        xdg.config.files = {
          "direnv/direnvrc".text = ''
            source ${pkgs.nix-direnv}/share/nix-direnv/direnvrc
          '';
          "fish/conf.d/direnv.fish".text = ''
            ${pkgs.direnv}/bin/direnv hook fish | source
          '';
        };

        files = lib.foldl' (acc: shell:
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
