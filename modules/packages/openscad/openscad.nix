{ ... }: {
  flake.nixosModules.openscad = { config, lib, ... }:
    lib.mkIf config.dotfiles.programs.threeDPrinting.enable {
      home-manager.users.${config.dotfiles.user.name} = { pkgs, ... }: {
        home.packages = [ pkgs.openscad-unstable ];
      };
    };
}
