{ ... }: {
  flake.nixosModules.udiskie = { config, lib, ... }:
    lib.mkIf config.dotfiles.programs.udiskie.enable {
      home-manager.users.${config.dotfiles.user.name} = { ... }: {
        services.udiskie = {
          enable = true;
          settings = {
            program_options = {
              file_manager = lib.concatStringsSep " " config.dotfiles.desktop.fileManagerCommand;
            };
          };
        };
      };
    };
}
