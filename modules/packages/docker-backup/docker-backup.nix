{ ... }: {
  flake.nixosModules.docker-backup = { config, lib, pkgs, ... }:
    let
      cfg = config.dotfiles.services.dockerBackup;
      hostname = config.dotfiles.network.hostname;
      sourceDir = "${config.dotfiles.programs.docker.basePath}/";
      backupDir = "/mnt/docker-backup/${hostname}";
      backupScript = pkgs.writeShellScript "docker-backup" ''
        SOURCE_DIR="${sourceDir}"
        BACKUP_DIR="${backupDir}"
        LOG_FILE="$BACKUP_DIR/log/docker_backup_$(date +%Y%m%d_%H%M%S).log"
        DATE_STAMP=$(date +%Y-%m-%d_%H:%M:%S)

        log_message() {
          echo "[$DATE_STAMP] $1" | tee -a "$LOG_FILE"
        }

        mkdir -p "$BACKUP_DIR/log"

        log_message "Starting Docker Configuration Backup."
        log_message "Source: $SOURCE_DIR"
        log_message "Destination: $BACKUP_DIR"

        if [ ! -d "$SOURCE_DIR" ]; then
          log_message "ERROR: Source directory '$SOURCE_DIR' does not exist. Aborting."
          exit 1
        fi

        log_message "Executing rsync for synchronization..."
        ${pkgs.rsync}/bin/rsync -avh --delete --exclude='log/' "$SOURCE_DIR" "$BACKUP_DIR" 2>&1 | tee -a "$LOG_FILE"

        RSYNC_EXIT_STATUS=''${PIPESTATUS[0]}
        if [ $RSYNC_EXIT_STATUS -eq 0 ]; then
          log_message "SUCCESS: Docker configuration backup completed successfully."
        elif [ $RSYNC_EXIT_STATUS -eq 24 ]; then
          log_message "WARNING: Backup completed, but some files vanished before transfer (exit code 24)."
        else
          log_message "FAILURE: Backup failed with rsync exit code $RSYNC_EXIT_STATUS."
          exit 1
        fi

        log_message "Backup script finished. Log saved to $LOG_FILE"
      '';
    in
    lib.mkIf cfg.enable {
      systemd.services.docker-backup = {
        description = "Docker configuration backup";
        serviceConfig = {
          Type = "oneshot";
          User = config.dotfiles.user.name;
          ExecStart = "${backupScript}";
        };
      };

      systemd.timers.docker-backup = {
        description = "Daily Docker backup at 3am";
        wantedBy = [ "timers.target" ];
        timerConfig = {
          OnCalendar = "*-*-* 03:00:00";
          Persistent = true;
        };
      };
    };
}
