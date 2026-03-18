{ ... }: {
  flake.nixosModules.backup = { config, lib, pkgs, ... }:
    let
      cfg = config.dotfiles.services.backup;

      backupScript = pkgs.writeShellScript "backup" ''
        set -euo pipefail

        MODE=""
        SOURCE=""
        DEST=""
        KEEP=""

        while [[ $# -gt 0 ]]; do
          case "$1" in
            --mode)        MODE="$2";   shift 2 ;;
            --source)      SOURCE="$2"; shift 2 ;;
            --destination) DEST="$2";   shift 2 ;;
            --keep)        KEEP="$2";   shift 2 ;;
            *) echo "Unknown argument: $1"; exit 1 ;;
          esac
        done

        if [[ -z "$MODE" || -z "$SOURCE" || -z "$DEST" ]]; then
          echo "ERROR: --mode, --source and --destination are required."
          exit 1
        fi

        if [[ ! -d "$SOURCE" ]]; then
          echo "ERROR: Source '$SOURCE' does not exist. Aborting."
          exit 1
        fi

        if [[ "$MODE" == "sync" ]]; then
          echo "Starting sync: $SOURCE -> $DEST"
          mkdir -p "$DEST"
          ${pkgs.rsync}/bin/rsync -avh --delete "$SOURCE" "$DEST"
          echo "Sync complete."

        elif [[ "$MODE" == "snapshot" ]]; then
          STAMP="snap_$(date +%Y-%m-%d_%H-%M-%S)"
          SNAP_DIR="$DEST/$STAMP"
          echo "Starting snapshot: $SOURCE -> $SNAP_DIR"
          mkdir -p "$SNAP_DIR"
          ${pkgs.rsync}/bin/rsync -avh "$SOURCE" "$SNAP_DIR"
          echo "Snapshot complete: $SNAP_DIR"

          if [[ -n "$KEEP" ]]; then
            echo "Pruning snapshots, keeping last $KEEP..."
            mapfile -t ALL_SNAPS < <(ls -1 "$DEST" | grep -E '^snap_[0-9]{4}-[0-9]{2}-[0-9]{2}_[0-9]{2}-[0-9]{2}-[0-9]{2}$' | sort)
            TOTAL=''${#ALL_SNAPS[@]}
            DELETE_COUNT=$(( TOTAL - KEEP ))
            if [[ $DELETE_COUNT -gt 0 ]]; then
              for i in $(seq 0 $(( DELETE_COUNT - 1 ))); do
                TARGET="$DEST/''${ALL_SNAPS[$i]}"
                echo "Removing old snapshot: $TARGET"
                rm -rf "$TARGET"
              done
            fi
            echo "Pruning done. Kept $KEEP snapshots."
          fi
        else
          echo "ERROR: Unknown mode '$MODE'."
          exit 1
        fi
      '';

      makeService = job: {
        name = "backup-${job.name}";
        value = {
          description = "Backup job: ${job.name}";
          serviceConfig = {
            Type = "oneshot";
            User = config.dotfiles.user.name;
            ExecStart = lib.concatStringsSep " " (
              [ "${backupScript}" "--mode" job.mode "--source" (lib.escapeShellArg job.source) "--destination" (lib.escapeShellArg job.destination) ]
              ++ lib.optional (job.keep != null) "--keep ${toString job.keep}"
            );
          };
        };
      };

      makeTimer = job: {
        name = "backup-${job.name}";
        value = {
          description = "Timer for backup job: ${job.name}";
          wantedBy = [ "timers.target" ];
          timerConfig = {
            OnCalendar = job.calendar;
            Persistent = true;
          };
        };
      };

    in
    lib.mkIf (cfg.enable && cfg.jobs != []) {
      systemd.services = lib.listToAttrs (map makeService cfg.jobs);
      systemd.timers   = lib.listToAttrs (map makeTimer  cfg.jobs);
    };
}
