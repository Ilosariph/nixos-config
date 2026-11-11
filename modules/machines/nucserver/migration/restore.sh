# nucserver-migrate-restore [--test] [--skip <stack>]...
# First thing after installing NixOS (see docs/nucserver.md). Unpacks the
# archives pre-switch.sh wrote to the NAS, pins every image to the digest it had
# on Ubuntu and brings the stacks back up.
#
# --test: use the archives of a pre-switch.sh --test run.
# --skip <stack>: don't start the stack with this directory name, repeatable.
set -euo pipefail

usage() {
    echo "usage: nucserver-migrate-restore [--test] [--skip <stack>]..." >&2
    exit 2
}

M=/mnt/docker-backup/nucserver-migration
skip=()
while [ $# -gt 0 ]; do
    case "$1" in
        --test)
            M=$M-test
            shift
            ;;
        --skip)
            [ $# -ge 2 ] || usage
            skip+=("$2")
            shift 2
            ;;
        *) usage ;;
    esac
done

if [ "$(id -u)" != 0 ]; then
    echo "run with sudo" >&2
    exit 1
fi
if [ "$(id -u simon)" != 1000 ]; then
    echo "simon must be uid 1000 (restored files, PUID of the containers)" >&2
    exit 1
fi
if [ ! -s "$M/stacks.txt" ]; then
    echo "$M/stacks.txt not found, is the NAS mounted?" >&2
    exit 1
fi
while read -r dir _; do
    if [ -e "$dir/docker-compose.yml" ]; then
        echo "$dir already restored, refusing to unpack over it" >&2
        exit 1
    fi
done < "$M/stacks.txt"

work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT

for archive in "$M"/*.tar; do
    name=$(basename "$archive" .tar)
    echo "==> Unpacking $name"
    # Checksum while reading, so the slow NAS read happens only once.
    mkfifo "$work/sum"
    sha256sum < "$work/sum" | cut -d' ' -f1 > "$work/have" &
    tee "$work/sum" < "$archive" | tar --numeric-owner --acls --xattrs -xpf - -C /
    wait $!
    rm "$work/sum"
    if [ "$(cat "$work/have")" != "$(cat "$M/$name.sha256")" ]; then
        echo "CHECKSUM MISMATCH: $archive" >&2
        exit 1
    fi
done

# Postgres refuses a data dir with the wrong owner or mode, Immich needs its
# root-owned tree: compare with what Ubuntu had before anything starts.
for tree in home/docker-data home/immich-backup; do
    recorded="$M/${tree//\//_}.perms"
    [ -f "$recorded" ] || continue
    echo "==> Checking owners and modes of /$tree"
    if ! diff "$recorded" <(cd / && LC_ALL=C find "$tree" -printf '%y %U:%G %m\n' | LC_ALL=C sort | uniq -c); then
        echo "OWNERS OR MODES DIFFER from Ubuntu in /$tree, not starting anything" >&2
        exit 1
    fi
done

echo "==> Creating external networks"
while read -r net; do
    docker network inspect "$net" >/dev/null 2>&1 || docker network create "$net"
done < "$M/networks.txt"

echo "==> Pinning images"
failed=()
pin() {
    local ref=$1 digest=$2
    # A ref that already contains a digest can't be tagged; pulling it is exact.
    if [ "$digest" = - ] || [[ "$ref" == *@* ]]; then
        docker pull "$ref"
    else
        docker pull "$digest" && docker tag "$digest" "$ref"
    fi
}
while read -r ref digest; do
    pin "$ref" "$digest" || failed+=("$ref")
done < "$M/images.txt"

skipped() {
    local s
    for s in "${skip[@]}"; do
        [ "$1" = "$s" ] && return 0
    done
    return 1
}

echo "==> Starting stacks"
down=()
while read -r dir; do
    if skipped "$(basename "$dir")"; then
        echo "-- $dir (skipped)"
        continue
    fi
    # Only the services that ran on Ubuntu, not everything in the file.
    mapfile -t services < <(awk -v d="$dir" '$1 == d {print $2}' "$M/stacks.txt")
    echo "-- $dir: ${services[*]}"
    (cd "$dir" && docker compose up -d "${services[@]}") || down+=("$dir")
done < <(awk '{print $1}' "$M/stacks.txt" | sort -u)

echo
docker ps --format 'table {{.Names}}\t{{.Status}}'
if [ ${#failed[@]} -gt 0 ] || [ ${#down[@]} -gt 0 ]; then
    echo
    [ ${#failed[@]} -gt 0 ] && printf 'Image pull failed: %s\n' "${failed[@]}"
    [ ${#down[@]} -gt 0 ] && printf 'Stack failed to start: %s\n' "${down[@]}"
    exit 1
fi
echo "All stacks up."
