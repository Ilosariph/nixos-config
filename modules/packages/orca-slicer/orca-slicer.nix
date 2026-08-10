{ ... }: {
  flake.nixosModules.orca-slicer = { config, lib, ... }:
    lib.mkIf config.dotfiles.desktop.enable {
      home-manager.users.${config.dotfiles.user.name} = { pkgs, ... }: {
        home.packages = [ pkgs.orca-slicer ];
      };
    };
}
