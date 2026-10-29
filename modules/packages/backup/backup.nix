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
        SQLITE=""
        RAW_EXCLUDES=()

        while [[ $# -gt 0 ]]; do
          case "$1" in
            --mode)        MODE="$2";   shift 2 ;;
            --source)      SOURCE="$2"; shift 2 ;;
            --destination) DEST="$2";   shift 2 ;;
            --keep)        KEEP="$2";   shift 2 ;;
            --exclude)     RAW_EXCLUDES+=("$2"); shift 2 ;;
            --sqlite)      SQLITE=1;    shift ;;
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

        EXCLUDES=()
        for e in "''${RAW_EXCLUDES[@]}"; do EXCLUDES+=("--exclude=$e"); done

        # --sqlite: copying a live SQLite DB (+ -wal) can yield a torn file. Take a
        # consistent copy via the online backup API (no need to stop the writer) into
        # a local staging dir, exclude the live files from rsync, then copy the staged
        # ones over. Anchored excludes (/foo/) are pruned so excluded dirs stay out.
        STAGE=""
        if [[ -n "$SQLITE" ]]; then
          STAGE=$(mktemp -d)
          trap 'rm -rf "$STAGE"' EXIT
          SRC_DIR="''${SOURCE%/}"
          PRUNE=()
          for e in "''${RAW_EXCLUDES[@]}"; do
            [[ "$e" == /* ]] && PRUNE+=(-path "$SRC_DIR''${e%/}" -o)
          done
          while IFS= read -r -d "" db; do
            [[ "$(head -c 15 "$db")" == "SQLite format 3" ]] || continue
            rel="''${db#"$SRC_DIR"/}"
            echo "SQLite backup: $rel"
            mkdir -p "$STAGE/$(dirname "$rel")"
            ${pkgs.sqlite}/bin/sqlite3 -cmd ".timeout 30000" "$db" ".backup '$STAGE/$rel'"
            for suffix in "" -wal -shm -journal; do EXCLUDES+=("--exclude=/$rel$suffix"); done
          done < <(find "$SRC_DIR" \( "''${PRUNE[@]}" -false \) -prune -o -type f \( -name '*.db' -o -name '*.sqlite' -o -name '*.sqlite3' \) -print0)
        fi

        if [[ "$MODE" == "sync" ]]; then
          echo "Starting sync: $SOURCE -> $DEST"
          mkdir -p "$DEST"
          ${pkgs.rsync}/bin/rsync -avh --no-owner --no-group --delete "''${EXCLUDES[@]}" "$SOURCE" "$DEST"
          [[ -n "$STAGE" ]] && ${pkgs.rsync}/bin/rsync -avh --no-owner --no-group "$STAGE/" "$DEST"
          echo "Sync complete."

        elif [[ "$MODE" == "snapshot" ]]; then
          STAMP="snap_$(date +%Y-%m-%d_%H-%M-%S)"
          SNAP_DIR="$DEST/$STAMP"
          echo "Starting snapshot: $SOURCE -> $SNAP_DIR"
          mkdir -p "$SNAP_DIR"
          ${pkgs.rsync}/bin/rsync -avh --no-owner --no-group "''${EXCLUDES[@]}" "$SOURCE" "$SNAP_DIR"
          [[ -n "$STAGE" ]] && ${pkgs.rsync}/bin/rsync -avh --no-owner --no-group "$STAGE/" "$SNAP_DIR"
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
            User = if job.user != null then job.user else config.dotfiles.user.name;
            ExecStart = lib.concatStringsSep " " (
              [ "${backupScript}" "--mode" job.mode "--source" (lib.escapeShellArg job.source) "--destination" (lib.escapeShellArg job.destination) ]
              ++ lib.optional (job.keep != null) "--keep ${toString job.keep}"
              ++ lib.concatMap (e: [ "--exclude" (lib.escapeShellArg e) ]) job.excludes
              ++ lib.optional job.sqlite "--sqlite"
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
