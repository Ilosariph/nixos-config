#!/usr/bin/env bash
# Last step on the Ubuntu VPS before nixos-anywhere (see docs/vps.md):
#   ssh root@<vps> 'bash -s' < modules/machines/vps/migration/pre-switch.sh
# Records what runs, stops every container (downtime starts here) and takes a
# restic snapshot tagged nixos-migration that vps-migrate-restore restores.
#
# With --test (rehearsal on vps-test): nothing is stopped. The DB containers
# are paused while restic runs, so their data dirs are crash-consistent; the
# apps using them stall for that time. Snapshot tag: nixos-migration-test.
#   ssh root@<vps> 'bash -s -- --test' < modules/machines/vps/migration/pre-switch.sh
set -euo pipefail

test_run=
case "${1:-}" in
    --test) test_run=1 ;;
    "") ;;
    *) echo "usage: pre-switch.sh [--test]" >&2; exit 2 ;;
esac

export HOME=/root
export RESTIC_REPOSITORY=sftp:storagebox:restic
export RESTIC_PASSWORD_FILE=/root/.restic-pass

# Same list as the dumps in backup.sh / backup.nix.
DBS=(dawarich_db umami-db-1 shlink_db FileDrop-DB monkeytype-mongodb)

M=/docker/.migration
mkdir -p "$M"

echo "==> Regular backup (DB dumps need the DB containers running)"
systemctl start backup.service

echo "==> Recording running stacks and images"
docker ps -q > "$M/running-ids.txt"

# Compose working dirs of running containers. Old dockge paths map to their
# /docker/compose copy; Pangolin is declared in nix now.
docker ps --format '{{.Label "com.docker.compose.project.working_dir"}}' | sort -u |
while read -r dir; do
    case "$dir" in
        "" | /docker/important/*) ;;
        /home/docker/dockge/stacks/*) echo "/docker/compose/${dir##*/}" ;;
        *) echo "$dir" ;;
    esac
done | sort -u > "$M/stacks.txt"

while read -r dir; do
    [ -d "$dir" ] || echo "WARNING: stack dir $dir does not exist, it won't come back up" >&2
done < "$M/stacks.txt"

# Tag -> repo digest of every running container, so unpinned tags (mariadb,
# redis, :latest) come back as the exact same image instead of upgrading.
docker ps -q | xargs docker inspect -f '{{.Config.Image}} {{.Image}}' | sort -u |
while read -r ref id; do
    digest=$(docker image inspect -f '{{range .RepoDigests}}{{println .}}{{end}}' "$id" | grep -m1 . || true)
    echo "$ref ${digest:--}"
done > "$M/images.txt"

echo "Stacks:"; sed 's/^/  /' "$M/stacks.txt"
echo "Images:"; sed 's/^/  /' "$M/images.txt"

if [ -n "$test_run" ]; then
    paused=()
    unpause() { [ ${#paused[@]} -eq 0 ] || docker unpause "${paused[@]}" >/dev/null; }
    trap unpause EXIT
    echo "==> Pausing DB containers for the snapshot: ${DBS[*]}"
    for c in "${DBS[@]}"; do
        docker pause "$c" >/dev/null && paused+=("$c")
    done

    echo "==> Test snapshot"
    restic backup /docker \
        --tag nixos-migration-test \
        --exclude-caches
    unpause
    paused=()
    restic snapshots --tag nixos-migration-test --latest 1

    echo
    echo "Done, prod kept running. Next: install vps-test (docs/vps.md, Test run)."
    exit 0
fi

echo "==> Stopping all containers and docker"
xargs -r docker stop < "$M/running-ids.txt"
systemctl stop docker.socket docker.service

# Containers are stopped, so the raw DB data dirs (excluded from the nightly
# backup) are consistent and can be restored as they are. /root, /opt, /etc
# and /home/docker are only for reference, the restore only takes /docker.
echo "==> Migration snapshot"
restic backup /docker /root /opt /etc /home/docker \
    --tag nixos-migration \
    --exclude-caches \
    --exclude /root/.cache \
    --exclude /root/snap
restic snapshots --tag nixos-migration --latest 1

echo
echo "Done. Docker is stopped; next: nixos-anywhere (docs/vps.md)."
echo "To abort instead: systemctl start docker && xargs docker start < $M/running-ids.txt"
