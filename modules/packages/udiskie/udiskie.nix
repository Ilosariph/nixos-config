{ ... }: {
  flake.nixosModules.udiskie = { config, lib, ... }:
    lib.mkIf config.dotfiles.programs.udiskie.enable {
      home-manager.users.${config.dotfiles.user.name} = { pkgs, ... }: {
        services.udiskie = {
          enable = true;
          settings = {
            program_options = {
              file_manager = "${pkgs.kitty}/bin/kitty ${pkgs.yazi}/bin/yazi";
            };
          };
        };
      };
    };
}
