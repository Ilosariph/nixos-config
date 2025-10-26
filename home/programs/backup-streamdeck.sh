#!/bin/sh

SOURCE_PATH="$HOME/.var/app/com.core447.StreamController"
OUTPUT_DIR="/mnt/simon/backup/streamdeck"
BACKUP_NAME="StreamController_Backup_$(date +%Y%m%d_%H%M%S).zip"

cd "$(dirname "$SOURCE_PATH")" || { echo "Error: Failed to change directory."; exit 1; }

zip -r "$OUTPUT_DIR/$BACKUP_NAME" .

if [ $? -eq 0 ]; then
    echo "File saved to: $OUTPUT_DIR/$BACKUP_NAME"
else
    echo "Backup failed."
    exit 1
fi

exit 0
