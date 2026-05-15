{ ... }: {
  flake.nixosModules.kitty = { config, lib, ... }:
    lib.mkIf config.dotfiles.programs.kitty.enable {
      home-manager.users.${config.dotfiles.user.name} = { pkgs, ... }: {
        programs.kitty = {
          enable = true;
          settings = {
            shell = "${pkgs.fish}/bin/fish";
          };
          shellIntegration = {
            mode = "enabled";
            enableFishIntegration = true;
          };
        };
      };
    };
}
