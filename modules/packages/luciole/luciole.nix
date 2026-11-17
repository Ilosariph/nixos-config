{ inputs, ... }: {
  flake.nixosModules.luciole = { config, lib, ... }:
    lib.mkIf (config.dotfiles.desktop.enable && config.dotfiles.desktop.fileManager == "luciole") {
      home-manager.sharedModules = [ inputs.luciole.homeModules.default ];
      home-manager.users.${config.dotfiles.user.name} = { ... }: {
        programs.luciole.enable = true;
      };
    };
}
