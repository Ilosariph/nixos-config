{ ... }: {
  flake.finixModules.docker = { config, lib, pkgs, modules, ... }:
    let
      registrySecret = "docker-registry";
      dockerPushScript = import ../../packages/docker/_docker-push.nix { inherit pkgs registrySecret; };
      enabled = config.dotfiles.programs.docker.enable;
    in {
      imports = [ modules.docker ];

      config = lib.mkMerge [
        { services.docker.enable = enabled; }

        (lib.mkIf enabled {
          environment.systemPackages = [ dockerPushScript pkgs.docker-buildx ];
        })

        (lib.mkIf (enabled && config.dotfiles.sops.enable) {
          sops.secrets.${registrySecret}.owner = config.dotfiles.user.name;
        })
      ];
    };
}
