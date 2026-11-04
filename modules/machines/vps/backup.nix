# Nightly restic backup of /docker (+ DB dumps) to the storagebox
# sub-account. Port of the Ubuntu /usr/local/bin/backup.sh + backup.timer.
{ config, lib, pkgs, ... }:
let
  storagebox = config.dotfiles.private.vps.storagebox;
  secrets = config.sops.secrets;

  env = {
    RESTIC_REPOSITORY = "sftp:storagebox:restic";
    RESTIC_PASSWORD_FILE = secrets.restic-password.path;
    RESTIC_CACHE_DIR = "/var/cache/restic";
  };

  # `restic-vps snapshots`, `restic-vps restore ...` as root with the repo preset.
  resticVps = pkgs.writeShellScriptBin "restic-vps" ''
    ${lib.concatStringsSep "\n" (lib.mapAttrsToList (k: v: "export ${k}=${lib.escapeShellArg v}") env)}
    exec ${pkgs.restic}/bin/restic "$@"
  '';
in
{
  sops.secrets.restic-password = { };
  sops.secrets.storagebox-ssh-key = { };
  sops.secrets.backup-discord-webhook = { };

  # restic's sftp backend runs `ssh storagebox -s sftp`.
  programs.ssh.extraConfig = ''
    Host storagebox
      HostName ${storagebox.host}
      User ${storagebox.user}
      Port ${toString storagebox.port}
      IdentityFile ${secrets.storagebox-ssh-key.path}
      ServerAliveInterval 60
  '';
  programs.ssh.knownHosts.storagebox = {
    hostNames = [ "[${storagebox.host}]:${toString storagebox.port}" ];
    publicKey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIICf9svRenC/PLKIL9nk6K/pxQgoiFC41wTNvoIncOxs";
  };

  environment.systemPackages = [ resticVps ];

  systemd.services.restic-backup = {
    description = "restic backup to the storagebox";
    wants = [ "network-online.target" "docker.service" ];
    after = [ "network-online.target" "docker.service" ];
    environment = env;
    path = with pkgs; [ restic docker openssh sqlite jq curl coreutils findutils gnugrep gnused hostname ];
    serviceConfig = {
      Type = "oneshot";
      CacheDirectory = "restic";
      Nice = 10;
      IOSchedulingClass = "idle";
    };
    script = ''
      set -euo pipefail
      HC=${lib.escapeShellArg (config.dotfiles.private.vps.backupHealthcheckUrl or "")}   # healthchecks.io ping URL (empty = disabled)
      DISCORD_WEBHOOK=$(cat ${secrets.backup-discord-webhook.path})
      DISCORD_NOTIFY="fail"    # comma-separated events to send: fail,start,success

      DUMPS=/root/db-dumps

      # Keep a copy of all output so failure messages can include the tail of it.
      LOG=$(mktemp)
      exec > >(tee "$LOG") 2>&1
      trap 'rm -f "$LOG"' EXIT

      ping_hc() { [ -n "$HC" ] && curl -fsS -m 10 --retry 3 "$HC$1" >/dev/null || true; }

      # notify <event> <color> <title> <description>
      notify() {
          [ -n "$DISCORD_WEBHOOK" ] && [[ ",$DISCORD_NOTIFY," == *",$1,"* ]] || return 0
          jq -n --arg t "$3" --arg d "$4" --argjson c "$2" \
              '{embeds: [{title: $t, description: $d, color: $c, timestamp: (now | todate)}]}' |
              curl -fsS -m 10 --retry 3 -H 'Content-Type: application/json' -d @- "$DISCORD_WEBHOOK" >/dev/null || true
      }

      on_fail() {
          local rc=$? line=$1 cmd=$2
          ping_hc /fail
          sleep 1   # let tee flush
          local tail
          tail=$(tail -n 20 "$LOG" | tail -c 1500 | sed 's/```/`\\`\\`/g')
          notify fail 15158332 "❌ Backup failed on $(hostname)" \
              "$(printf 'Line %s: `%s` (exit %s) after %ss\n```\n%s\n```' "$line" "$cmd" "$rc" "$SECONDS" "$tail")"
      }
      trap 'on_fail $LINENO "$BASH_COMMAND"' ERR

      ping_hc /start
      notify start 3447003 "▶️ Backup started on $(hostname)" ""

      rm -rf "$DUMPS"
      mkdir -p "$DUMPS/sqlite"
      chmod 700 "$DUMPS"

      # Postgres (superuser = POSTGRES_USER of the container)
      for c in dawarich_db umami-db-1; do
          docker exec "$c" sh -c 'pg_dumpall -U "$POSTGRES_USER"' > "$DUMPS/$c.sql"
      done

      # MariaDB
      for c in shlink_db FileDrop-DB; do
          docker exec "$c" sh -c 'MYSQL_PWD="$MARIADB_ROOT_PASSWORD" mariadb-dump -uroot --all-databases --single-transaction --routines --events' > "$DUMPS/$c.sql"
      done

      # MongoDB (no auth)
      docker exec monkeytype-mongodb mongodump --archive --quiet > "$DUMPS/monkeytype-mongodb.archive"

      # SQLite: consistent online copy of every live DB under /docker/data and
      # /docker/important (Pangolin's db.sqlite), skipping app-made backup dirs
      find /docker/data /docker/important -type f \( -name '*.db' -o -name '*.sqlite' -o -name '*.sqlite3' \) \
          -not -path '*/backups/*' -not -path '*/backup/*' -print0 |
      while IFS= read -r -d "" f; do
          [ "$(head -c 15 "$f")" = "SQLite format 3" ] || continue
          sqlite3 "$f" ".timeout 10000" ".backup '$DUMPS/sqlite/$(echo "''${f#/docker/}" | tr / _)'"
      done

      # Raw data dirs of the dumped server DBs are excluded: copying them live gives inconsistent files.
      restic backup /docker "$DUMPS" \
          --exclude-caches \
          --exclude /docker/data/dawarich/db \
          --exclude /docker/data/umami/postgres \
          --exclude /docker/data/shlink/db \
          --exclude /docker/data/filedrop/database \
          --exclude /docker/data/monkeytype/mongodb \
          --exclude '*.db-wal' --exclude '*.db-shm' --exclude '*.sqlite-wal' --exclude '*.sqlite-shm'

      restic forget --keep-daily 14 --keep-weekly 8 --keep-monthly 12
      if [ "$(date +%d)" = 01 ]; then
          restic prune --max-unused 10%
          restic check --read-data-subset 5%
      fi

      ping_hc ""
      notify success 3066993 "✅ Backup finished on $(hostname)" \
          "$(printf 'Took %dm %ds\n%s' $((SECONDS / 60)) $((SECONDS % 60)) \
              "$(grep -E '^(Files:|Added to the repository:|snapshot [0-9a-f]+ saved)' "$LOG" || true)")"
    '';
  };

  systemd.timers.restic-backup = {
    description = "Nightly restic backup";
    wantedBy = [ "timers.target" ];
    timerConfig = {
      OnCalendar = "*-*-* 02:30";
      RandomizedDelaySec = "15m";
      Persistent = true;
    };
  };
}
