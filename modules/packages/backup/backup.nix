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

      restoreScript = pkgs.writeShellScript "backup-restore" ''
        set -euo pipefail

        MODE=""
        SOURCE=""
        DEST=""

        while [[ $# -gt 0 ]]; do
          case "$1" in
            --mode)        MODE="$2";   shift 2 ;;
            --source)      SOURCE="$2"; shift 2 ;;
            --destination) DEST="$2";   shift 2 ;;
            *) echo "Unknown argument: $1"; exit 1 ;;
          esac
        done

        if [[ -z "$MODE" || -z "$SOURCE" || -z "$DEST" ]]; then
          echo "ERROR: --mode, --source and --destination are required."
          exit 1
        fi

        if [[ -d "$SOURCE" ]]; then
          echo "Source '$SOURCE' already exists. Nothing to restore."
          exit 0
        fi

        RESTORE_FROM=""
        if [[ "$MODE" == "snapshot" ]]; then
          if [[ ! -d "$DEST" ]]; then
            echo "WARNING: Backup destination '$DEST' not found (share not mounted?). Skipping restore."
            exit 0
          fi
          LATEST=$(ls -1 "$DEST" | grep -E '^snap_[0-9]{4}-[0-9]{2}-[0-9]{2}_[0-9]{2}-[0-9]{2}-[0-9]{2}$' | sort | tail -1 || true)
          if [[ -z "$LATEST" ]]; then
            echo "WARNING: No snapshots found under '$DEST'. Skipping restore."
            exit 0
          fi
          RESTORE_FROM="$DEST/$LATEST"
        elif [[ "$MODE" == "sync" ]]; then
          RESTORE_FROM="$DEST"
        else
          echo "ERROR: Unknown mode '$MODE'."
          exit 1
        fi

        if [[ ! -d "$RESTORE_FROM" ]]; then
          echo "WARNING: Backup '$RESTORE_FROM' not found. Skipping restore."
          exit 0
        fi

        echo "Source '$SOURCE' is missing. Restoring from '$RESTORE_FROM'..."
        mkdir -p "$SOURCE"
        ${pkgs.rsync}/bin/rsync -avh "$RESTORE_FROM/" "$SOURCE/"
        echo "Restore complete: $RESTORE_FROM -> $SOURCE"
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

      makeRestoreService = job: {
        name = "backup-restore-${job.name}";
        value = {
          description = "Restore ${job.name} from latest backup if source is missing";
          wantedBy = [ "multi-user.target" ];
          before   = job.restoreBefore;
          unitConfig = {
            ConditionPathExists = "!${job.source}";
            RequiresMountsFor   = job.destination;
          };
          serviceConfig = {
            Type = "oneshot";
            User = config.dotfiles.user.name;
            ExecStart = lib.concatStringsSep " " [
              "${restoreScript}" "--mode" job.mode
              "--source" (lib.escapeShellArg job.source)
              "--destination" (lib.escapeShellArg job.destination)
            ];
          };
        };
      };

    in
    lib.mkIf (cfg.enable && cfg.jobs != []) {
      systemd.services =
        lib.listToAttrs (map makeService cfg.jobs)
        // lib.listToAttrs (map makeRestoreService (lib.filter (j: j.restoreOnMissing) cfg.jobs));
      systemd.timers   = lib.listToAttrs (map makeTimer  cfg.jobs);
    };
}
