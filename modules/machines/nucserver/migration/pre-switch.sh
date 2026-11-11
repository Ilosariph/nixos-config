#!/usr/bin/env bash
# Last step on Ubuntu before nixos-anywhere (see docs/nucserver.md):
#   scp modules/machines/nucserver/migration/pre-switch.sh simon@<nuc>:/tmp/
#   ssh -t simon@<nuc> sudo bash /tmp/pre-switch.sh
# Records what runs, stops every container and docker (downtime starts here)
# and writes tar archives of everything the install wipes to the NAS. Tar, not
# rsync: the CIFS share can't hold owners and modes, the postgres dir needs them.
#
# --test: nothing is stopped; archives only the stack dirs plus a DB dump to a
# separate directory. Proves the NAS path and measures throughput.
# --no-verify: skip reading the archives back before the wipe.
# --drop <path>: leave this directory out of the archives, repeatable.
set -euo pipefail

usage() {
    echo "usage: pre-switch.sh [--test] [--no-verify] [--drop <path>]..." >&2
    exit 2
}

test_run=
verify=1
DROP=()
while [ $# -gt 0 ]; do
    case "$1" in
        --test) test_run=1; shift ;;
        --no-verify) verify=; shift ;;
        --drop)
            [ $# -ge 2 ] || usage
            [ -e "$2" ] || echo "WARNING: --drop $2 does not exist" >&2
            DROP+=("${2#/}")
            shift 2
            ;;
        *) usage ;;
    esac
done

[ "$(id -u)" = 0 ] || { echo "run with sudo" >&2; exit 1; }
export PATH="$PATH:/snap/bin"

M=/mnt/docker-backup/nucserver-migration${test_run:+-test}
mkdir -p "$M"

# Paths without leading slash, relative to /.
TREES=(home/simon/docker home/docker-data home/immich-backup)
# Owner + mode histogram; the restore compares it before starting anything.
PERM_TREES=(home/docker-data home/immich-backup)
perms() {
    (cd / && LC_ALL=C find "$1" -printf '%y %U:%G %m\n' | LC_ALL=C sort | uniq -c)
}

needed=$(du -sxk "${TREES[@]/#//}" | awk '{s += $1} END {print s}')
free=$(df --output=avail -k "$M" | tail -1)
echo "Need $((needed / 1048576)) GiB, NAS has $((free / 1048576)) GiB free"
[ "$free" -gt "$needed" ] || { echo "not enough space on the NAS" >&2; exit 1; }

echo "==> Recording running stacks and images"
docker ps -q > "$M/running-ids.txt"

# "<compose dir> <service>" of what runs now, so stopped services stay stopped.
docker ps --format '{{.Label "com.docker.compose.project.working_dir"}} {{.Label "com.docker.compose.service"}}' |
    grep -v '^ ' | sort -u > "$M/stacks.txt"

stray=$(docker ps --format '{{.Names}} {{.Label "com.docker.compose.project"}}' | awk 'NF == 1 {print $1}')
[ -z "$stray" ] || echo "WARNING: not started by compose, won't come back up: $stray" >&2

# Networks the compose files declare as external have to exist before `up`.
docker network ls --format '{{.Name}} {{.Label "com.docker.compose.network"}}' |
    awk 'NF == 1 && $1 !~ /^(bridge|host|none)$/ {print $1}' > "$M/networks.txt"

# Tag -> repo digest of every running container, so :latest comes back as the
# exact same image instead of upgrading.
docker ps -q | xargs docker inspect -f '{{.Config.Image}} {{.Image}}' | sort -u |
while read -r ref id; do
    digest=$(docker image inspect -f '{{range .RepoDigests}}{{println .}}{{end}}' "$id" | grep -m1 . || true)
    echo "$ref ${digest:--}"
done > "$M/images.txt"

echo "Stacks:"; sed 's/^/  /' "$M/stacks.txt"
echo "Networks:"; sed 's/^/  /' "$M/networks.txt"
echo "Images:"; sed 's/^/  /' "$M/images.txt"

echo "==> Database dump (extra safety, the raw dir is archived too)"
docker exec immich_postgres pg_dumpall --clean --if-exists --username=postgres | gzip > "$M/immich_db_pre-switch.sql.gz"
ls -lh "$M/immich_db_pre-switch.sql.gz"

archive() {
    local name=$1
    shift
    echo "==> Archiving $name: $*"
    # tar exits 1 for files changing while read; only expected in --test.
    { tar --numeric-owner --acls --xattrs "${DROP[@]/#/--exclude=}" -C / -cf - "$@" || { rc=$?; [ -n "$test_run" ] && [ "$rc" -eq 1 ]; }; } |
        tee "$M/$name.tar" | sha256sum | cut -d' ' -f1 > "$M/$name.sha256"
    ls -lh "$M/$name.tar"
}

check() {
    local name=$1 want have
    want=$(cat "$M/$name.sha256")
    have=$(sha256sum "$M/$name.tar" | cut -d' ' -f1)
    if [ "$want" != "$have" ]; then
        echo "CHECKSUM MISMATCH: $M/$name.tar, do NOT install" >&2
        exit 1
    fi
    echo "OK: $name"
}

if [ -n "$test_run" ]; then
    time archive stacks home/simon/docker
    sync; echo 3 > /proc/sys/vm/drop_caches
    time check stacks
    echo
    echo "Done, nothing was stopped. Test files: $M (delete afterwards)."
    exit 0
fi

echo "==> Stopping all containers and docker"
xargs -r docker stop < "$M/running-ids.txt"
snap stop docker

echo "==> Recording owners and modes"
for tree in "${PERM_TREES[@]}"; do
    perms "$tree" > "$M/${tree//\//_}.perms"
    sed "s|^|  $tree: |" "$M/${tree//\//_}.perms"
done

names=()
for tree in "${TREES[@]}"; do
    name=${tree//\//_}
    archive "$name" "$tree"
    names+=("$name")
done

# Reference only, the restore doesn't touch it. Not the SSH host keys: those go
# through --extra-files and shouldn't sit on a share.
tar --numeric-owner -C / --exclude='etc/ssh/ssh_host_*' \
    -cf "$M/reference.tar.ignore" etc home/simon/scripts home/simon/backup-immich.sh

if [ -n "$verify" ]; then
    echo "==> Reading the archives back from the NAS"
    sync; echo 3 > /proc/sys/vm/drop_caches
    for name in "${names[@]}"; do check "$name"; done
fi

echo
echo "Done. Docker is stopped; next: nixos-anywhere (docs/nucserver.md)."
echo "To abort instead: snap start docker && xargs docker start < $M/running-ids.txt"
