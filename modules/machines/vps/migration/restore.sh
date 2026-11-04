# vps-migrate-restore [--test] [--skip <stack>]...
# First thing after installing NixOS (see docs/vps.md). Restores /docker from
# the nixos-migration snapshot, starts Pangolin, pins every image to the digest
# it had on Ubuntu and brings the stacks back up.
#
# --test (vps-test only): restores the nixos-migration-test snapshot. Pass
# --skip for every stack that would act on prod or notify people (docs/vps.md).
# --skip <stack>: don't start /docker/compose/<stack>, repeatable.
set -euo pipefail

usage() {
    echo "usage: vps-migrate-restore [--test] [--skip <stack>]..." >&2
    exit 2
}

tag=nixos-migration
skip=()
test_run=
while [ $# -gt 0 ]; do
    case "$1" in
        --test)
            test_run=1
            tag=nixos-migration-test
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

# vps-test runs with prod's data and credentials: never the full set there.
if [ "$(cat /etc/machine-name)" = vps-test ] && [ -z "$test_run" ]; then
    echo "this is vps-test, use --test" >&2
    exit 1
fi

M=/docker/.migration

if [ -e /docker/important/Pangolin/config/db/db.sqlite ]; then
    echo "/docker already has Pangolin state, refusing to restore over it" >&2
    exit 1
fi

echo "==> Restoring /docker from the latest $tag snapshot"
restic-vps snapshots --tag "$tag" --latest 1
restic-vps restore latest --tag "$tag" --include /docker --target /

echo "==> Starting Pangolin (gated on the restored state until now)"
systemctl start docker-pangolin.service docker-gerbil.service docker-traefik.service

failed=()

# pin <ref> <digest|->: pull the exact image the container ran on Ubuntu and
# tag it as the ref compose asks for, so `compose up` doesn't pull a newer one.
pin() {
    local ref=$1 digest=$2
    if [ "$digest" = - ]; then
        docker pull "$ref"
    else
        docker pull "$digest" && docker tag "$digest" "$ref"
    fi
}

pin_all() {
    local filter=$1 ref digest
    while read -r ref digest; do
        [[ "$ref" =~ $filter ]] || continue
        pin "$ref" "$digest" || failed+=("$ref")
    done < "$M/images.txt"
}

skipped() {
    local s
    for s in "${skip[@]}"; do
        [ "$1" = "/docker/compose/$s" ] && return 0
    done
    return 1
}

# The registry serves the dockerregistry.* images, so it has to run first.
registry_dir=$(grep -m1 '/docker-registry$' "$M/stacks.txt" || true)
if [ -n "$registry_dir" ]; then
    echo "==> Registry stack"
    pin_all '^registry(:|$)'
    (cd "$registry_dir" && docker compose up -d)
    echo "Waiting for Pangolin + registry to route..."
    sleep 30
fi

echo "==> Pinning images"
pin_all '.'

# Retry once: the registry route may have needed longer.
if [ ${#failed[@]} -gt 0 ]; then
    echo "==> Retrying ${#failed[@]} failed pulls in 60s"
    sleep 60
    retry=("${failed[@]}")
    failed=()
    for ref in "${retry[@]}"; do
        digest=$(awk -v r="$ref" '$1 == r { print $2; exit }' "$M/images.txt")
        pin "$ref" "$digest" || failed+=("$ref")
    done
fi

echo "==> Starting stacks"
down=()
while read -r dir; do
    [ "$dir" = "$registry_dir" ] && continue
    if skipped "$dir"; then
        echo "-- $dir (skipped)"
        continue
    fi
    echo "-- $dir"
    (cd "$dir" && docker compose up -d) || down+=("$dir")
done < "$M/stacks.txt"

echo
docker ps --format 'table {{.Names}}\t{{.Status}}'
if [ ${#failed[@]} -gt 0 ] || [ ${#down[@]} -gt 0 ]; then
    echo
    [ ${#failed[@]} -gt 0 ] && printf 'Image pull failed: %s\n' "${failed[@]}"
    [ ${#down[@]} -gt 0 ] && printf 'Stack failed to start: %s\n' "${down[@]}"
    exit 1
fi
echo "All stacks up."
