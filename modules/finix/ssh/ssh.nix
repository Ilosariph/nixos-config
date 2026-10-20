{ ... }: {
  flake.finixModules.ssh = { config, lib, modules, ... }:
    let
      cfg = config.dotfiles.services.ssh;
    in {
      imports = [ modules.openssh ];

      services.openssh.enable = cfg.enable;

      sops.secrets = lib.mkIf (cfg.authorizedKeySecret != null) {
        ${cfg.authorizedKeySecret} = {
          path = "/home/${config.dotfiles.user.name}/.ssh/authorized_keys";
          owner = config.dotfiles.user.name;
          group = "users";
          mode = "0400";
        };
      };
    };
}
