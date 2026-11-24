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
        STAGED=()
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
            STAGED+=("$rel")
            for suffix in "" -wal -shm -journal; do EXCLUDES+=("--exclude=/$rel$suffix"); done
          done < <(find "$SRC_DIR" \( "''${PRUNE[@]}" -false \) -prune -o -type f \( -name '*.db' -o -name '*.sqlite' -o -name '*.sqlite3' \) -print0)
        fi

        if [[ "$MODE" == "sync" ]]; then
          echo "Starting sync: $SOURCE -> $DEST"
          mkdir -p "$DEST"
          ${pkgs.rsync}/bin/rsync -avh --no-owner --no-group --delete "''${EXCLUDES[@]}" "$SOURCE" "$DEST"
          [[ -n "$STAGE" ]] && ${pkgs.rsync}/bin/rsync -avh --no-owner --no-group "$STAGE/" "$DEST"
          # --delete skips excluded paths, so -wal/-shm from older mirrors (live copies) would stay
          # next to the clean .backup copy; on restore SQLite replays that stale WAL onto it.
          for rel in "''${STAGED[@]}"; do
            for suffix in -wal -shm -journal; do rm -f "$DEST/$rel$suffix"; done
          done
          echo "Sync complete."

        elif [[ "$MODE" == "snapshot" ]]; then
          # Written as snap_*.partial and renamed when done, so a NAS-side backup
          # running at the same time (excluding *.partial) never reads a half-written
          # snapshot. Leftovers from aborted runs are removed first.
          STAMP="snap_$(date +%Y-%m-%d_%H-%M-%S)"
          SNAP_DIR="$DEST/$STAMP"
          WORK_DIR="$SNAP_DIR.partial"
          mkdir -p "$DEST"
          find "$DEST" -mindepth 1 -maxdepth 1 -type d -name 'snap_*.partial' -exec rm -rf {} +
          echo "Starting snapshot: $SOURCE -> $SNAP_DIR"
          mkdir -p "$WORK_DIR"
          ${pkgs.rsync}/bin/rsync -avh --no-owner --no-group "''${EXCLUDES[@]}" "$SOURCE" "$WORK_DIR"
          [[ -n "$STAGE" ]] && ${pkgs.rsync}/bin/rsync -avh --no-owner --no-group "$STAGE/" "$WORK_DIR"
          mv "$WORK_DIR" "$SNAP_DIR"
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
                # Rename first (instant) so a concurrent NAS backup skips it instead of
                # hitting files vanishing during the slow rm.
                mv "$TARGET" "$TARGET.partial"
                rm -rf "$TARGET.partial"
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
          onFailure = [ "backup-failure-notify@%n.service" ];
          serviceConfig = {
            Type = "oneshot";
            User = if job.user != null then job.user else config.dotfiles.user.name;
            ExecStart = lib.concatStringsSep " " (
              [ "${backupScript}" "--mode" job.mode "--source" (lib.escapeShellArg job.source) "--destination" (lib.escapeShellArg job.destination) ]
              ++ lib.optional (job.keep != null) "--keep ${toString job.keep}"
              ++ lib.concatMap (e: [ "--exclude" (lib.escapeShellArg e) ]) job.excludes
              ++ lib.optional job.sqlite "--sqlite"
            );
          } // lib.optionalAttrs (job.preCommand != null) {
            ExecStartPre = pkgs.writeShellScript "backup-${job.name}-pre" ''
              set -euo pipefail
              ${job.preCommand}
            '';
          };
        };
      };

      # Discord message with the job's log tail when a backup unit fails (NAS down,
      # rsync error, disk full, ...). Separate root unit so job users never need the
      # webhook secret. Best effort: a failed post only logs.
      notifyScript = pkgs.writeShellScript "backup-failure-notify" ''
        set -uo pipefail
        UNIT="$1"
        WEBHOOK=$(cat ${config.sops.secrets.backup-discord-webhook.path})
        INV=$(${pkgs.systemd}/bin/systemctl show -p InvocationID --value "$UNIT")
        LOG=$(${pkgs.systemd}/bin/journalctl --no-pager -o cat _SYSTEMD_INVOCATION_ID="$INV" | tail -n 20 | tail -c 1500 | sed 's/```/`\\`\\`/g')
        DESC=$(printf '`%s` failed\n```\n%s\n```' "$UNIT" "$LOG")
        ${pkgs.jq}/bin/jq -n --arg t "❌ Backup failed on $(${pkgs.hostname}/bin/hostname)" --arg d "$DESC" \
          '{embeds: [{title: $t, description: $d, color: 15158332, timestamp: (now | todate)}]}' |
          ${pkgs.curl}/bin/curl -fsS -m 10 --retry 3 -H 'Content-Type: application/json' -d @- "$WEBHOOK" >/dev/null \
          || echo "Discord notification failed"
      '';

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
      systemd.services = lib.listToAttrs (map makeService cfg.jobs) // {
        "backup-failure-notify@" = {
          description = "Discord notification for failed %i";
          serviceConfig = {
            Type = "oneshot";
            ExecStart = "${notifyScript} %i";
          };
        };
      };
      systemd.timers   = lib.listToAttrs (map makeTimer  cfg.jobs);

      sops.secrets.backup-discord-webhook.sopsFile = config.dotfiles.sops.sharedSecretsFile;
    };
}
