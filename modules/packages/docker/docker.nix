{ ... }: {
  flake.nixosModules.docker = { config, lib, pkgs, ... }:
    let
      registrySecret = "docker-registry";

      dockerPushScript = pkgs.writeShellApplication {
        name = "docker-push";
        runtimeInputs = [ pkgs.git ];
        text = ''
          # docker-push <image> [-r registry] [-t tag] [-p platform]
          #   Builds the Dockerfile in the current dir with buildx and pushes it.
          #   registry defaults to the sops secret ${registrySecret}.
          #   tag defaults to "latest" + the short commit hash (when in a git repo).
          usage() {
            echo "usage: docker-push <image> [-r registry] [-t tag] [-p platform]" >&2
            exit 2
          }

          [ $# -ge 1 ] || usage
          case "$1" in -*) usage ;; esac
          image="$1"
          shift

          registry=""
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

          if [ -z "$registry" ]; then
            secret="/run/secrets/${registrySecret}"
            if [ -r "$secret" ]; then
              registry="$(cat "$secret")"
            else
              echo "docker-push: no registry given and $secret not readable" >&2
              exit 1
            fi
          fi

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
      { virtualisation.docker.enable = config.dotfiles.programs.docker.enable; }

      (lib.mkIf config.dotfiles.programs.docker.enable {
        environment.systemPackages = [ dockerPushScript ];
      })

      (lib.mkIf (config.dotfiles.programs.docker.enable && config.dotfiles.sops.enable) {
        sops.secrets.${registrySecret}.owner = config.dotfiles.user.name;
      })
    ];
}
