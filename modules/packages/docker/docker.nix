{ ... }: {
  flake.nixosModules.docker = { config, lib, pkgs, ... }:
    let
      registry = config.dotfiles.private.docker.registry;

      dockerPushScript = pkgs.writeShellApplication {
        name = "docker-push";
        runtimeInputs = [ pkgs.git ];
        text = ''
          # docker-push <image> [-r registry] [-t tag] [-p platform]
          #   Builds the Dockerfile in the current dir with buildx and pushes it.
          #   registry defaults to dotfiles.private.docker.registry.
          #   tag defaults to "latest" + the short commit hash (when in a git repo).
          usage() {
            echo "usage: docker-push <image> [-r registry] [-t tag] [-p platform]" >&2
            exit 2
          }

          [ $# -ge 1 ] || usage
          case "$1" in -*) usage ;; esac
          image="$1"
          shift

          registry="${registry}"
          tag=""
          platform="linux/amd64"
          while getopts "r:t:p:h" opt; do
            case "$opt" in
              r) registry="$OPTARG" ;;
              t) tag="$OPTARG" ;;
              p) platform="$OPTARG" ;;
              *) usage ;;
            esac
          done

          tags=()
          if [ -n "$tag" ]; then
            tags+=(-t "$registry/$image:$tag")
          else
            tags+=(-t "$registry/$image:latest")
            if hash="$(git rev-parse --short HEAD 2>/dev/null)"; then
              tags+=(-t "$registry/$image:$hash")
            fi
          fi

          echo "Pushing: ''${tags[*]}"
          # Skip buildx git provenance labels: under sudo, root git rejects the user-owned repo
          sudo BUILDX_GIT_INFO=0 docker buildx build --platform "$platform" "''${tags[@]}" --push .
        '';
      };
    in
    lib.mkMerge [
      {
        virtualisation.docker.enable = config.dotfiles.programs.docker.enable;
        # Rootless, daemonless `podman build` for agents to verify Dockerfiles without sudo
        virtualisation.podman.enable = config.dotfiles.programs.docker.enable;
        # Resolve short names (node:22-alpine) like docker does; docker.io only, so no ambiguity prompt
        virtualisation.containers.registries.settings.unqualified-search-registries = [ "docker.io" ];
      }

      (lib.mkIf config.dotfiles.programs.docker.enable {
        environment.systemPackages = [ dockerPushScript ];
      })
    ];
}
