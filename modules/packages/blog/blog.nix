{ ... }: {
  flake.nixosModules.blog = { config, lib, pkgs, ... }:
    lib.mkIf config.dotfiles.programs.blog.enable {
      dotfiles.direnv.shells = [{
        dir = "blog";
        packages = [ pkgs.hugo pkgs.git ];
      }];
    };
}
