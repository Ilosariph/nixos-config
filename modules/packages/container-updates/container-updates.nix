{ ... }: {
  # On switch/test (deploy-rs, nh, pull-switch), list oci-containers whose registry image is newer
  # than the local one, or that still run an older image than the local one. Info only: containers
  # use pull = "missing", so updating stays a manual `pull` + restart.
  flake.nixosModules.container-updates = { config, lib, pkgs, ... }:
    let
      oci = config.virtualisation.oci-containers;
      cli =
        if oci.backend == "podman"
        then "${config.virtualisation.podman.package}/bin/podman"
        else "${config.virtualisation.docker.package}/bin/docker";
      # Digest-pinned and nix-built (imageFile) images can't drift.
      checked = lib.filterAttrs (_: c: c.imageFile == null && !(lib.hasInfix "@sha256:" c.image)) oci.containers;

      checkOne = name: c: ''
        (
          img=${lib.escapeShellArg c.image}
          unit=${lib.escapeShellArg "${oci.backend}-${name}"}
          local_digests=$(${cli} image inspect --format '{{json .RepoDigests}}' "$img" 2>/dev/null) || exit 0
          [ "$local_digests" = "null" ] && exit 0
          # Hash the raw manifest bytes as-is ($(...) would strip a trailing newline).
          if remote=$(set -o pipefail; ${pkgs.coreutils}/bin/timeout 15 ${pkgs.skopeo}/bin/skopeo inspect --raw "docker://$img" 2>/dev/null \
                | ${pkgs.coreutils}/bin/sha256sum | ${pkgs.coreutils}/bin/cut -d' ' -f1); then
            remote="sha256:$remote"
            case "$local_digests" in
              *"$remote"*) ;;
              *) printf '  %s: newer image in registry (%s)\n    %s pull %s && systemctl restart %s\n' \
                   ${name} "$img" ${oci.backend} "$img" "$unit" ;;
            esac
          else
            echo "  ${name}: couldn't check registry ($img)"
          fi
          running=$(${cli} inspect --format '{{.Image}}' ${lib.escapeShellArg name} 2>/dev/null) || exit 0
          latest=$(${cli} image inspect --format '{{.Id}}' "$img" 2>/dev/null) || exit 0
          [ "''${running#sha256:}" = "''${latest#sha256:}" ] \
            || printf '  %s: runs an older image than the pulled %s\n    systemctl restart %s\n' ${name} "$img" "$unit"
        ) > "$_cuTmp/${name}" &
      '';
    in
    lib.mkIf (checked != { }) {
      system.activationScripts.containerUpdates = {
        # Not at boot (no network yet, and nobody reads it there), not on dry-activate / boot.
        text = ''
          case "''${NIXOS_ACTION:-}" in
            switch|test)
              _cuTmp=$(${pkgs.coreutils}/bin/mktemp -d)
              ${lib.concatStrings (lib.mapAttrsToList checkOne checked)}
              wait
              _cuOut=$(${pkgs.coreutils}/bin/cat "$_cuTmp"/*)
              rm -rf "$_cuTmp"
              if [ -n "$_cuOut" ]; then
                echo "container updates available:"
                echo "$_cuOut"
              fi
              ;;
          esac
        '';
      };
    };
}
