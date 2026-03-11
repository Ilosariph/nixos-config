{ ... }: {
  flake.nixosModules.swappy = { config, lib, ... }:
    lib.mkIf config.dotfiles.programs.swappy.enable {
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
      };
    };
}
