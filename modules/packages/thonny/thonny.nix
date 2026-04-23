{ ... }: {
  flake.nixosModules.thonny = { config, lib, pkgs, ... }:
    lib.mkIf config.dotfiles.programs.thonny.enable {
      home-manager.users.${config.dotfiles.user.name} = { ... }: {
        home.packages = [ pkgs.thonny ];
      };

      users.users.${config.dotfiles.user.name}.extraGroups = [ "dialout" ];
    };
}
