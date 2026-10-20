{ ... }: {
  flake.nixosModules.docker = { config, lib, pkgs, ... }:
    let
      registrySecret = "docker-registry";

      dockerPushScript = import ./_docker-push.nix { inherit pkgs registrySecret; };
    in
    lib.mkMerge [
      { virtualisation.docker.enable = config.dotfiles.programs.docker.enable; }

      (lib.mkIf config.dotfiles.programs.docker.enable {
        environment.systemPackages = [ dockerPushScript ];
      })

      (lib.mkIf (config.dotfiles.programs.docker.enable && config.dotfiles.sops.enable) {
        sops.secrets.${registrySecret}.owner = config.dotfiles.user.name;
      })
    ];
}
