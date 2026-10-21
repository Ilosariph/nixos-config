#!/usr/bin/env bash
# Usage: ./secrets.sh [edit [file]|update]
#   edit [file]  Pull the private nix-secrets clone, open <file> (default
#                secrets.yaml) in sops, commit + push if changed, then bump the
#                nix-secrets input in flake.lock.
#   update       Only bump the nix-secrets input (secrets changed elsewhere).
# Clone location: $NIX_SECRETS_DIR (default ~/nix-secrets). See docs/secrets.md.
set -euo pipefail

REPO="git@github.com:Ilosariph/nix-secrets.git"
SECRETS_DIR="${NIX_SECRETS_DIR:-$HOME/nix-secrets}"
FLAKE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MODE="${1:-edit}"

update_lock() {
  nix flake update nix-secrets --flake "$FLAKE_DIR"
  echo "flake.lock updated. Commit it, then ./build.sh / deploy as usual."
}

case "$MODE" in
  edit)
    FILE="${2:-secrets.yaml}"
    if [[ ! -d "$SECRETS_DIR/.git" ]]; then
      git clone "$REPO" "$SECRETS_DIR"
    fi
    git -C "$SECRETS_DIR" pull --ff-only
    # Run from inside the clone so sops picks up its .sops.yaml.
    (cd "$SECRETS_DIR" && sops "$FILE")
    if [[ -z "$(git -C "$SECRETS_DIR" status --porcelain)" ]]; then
      echo "No changes."
      exit 0
    fi
    git -C "$SECRETS_DIR" add -A
    git -C "$SECRETS_DIR" commit -m "update $FILE"
    git -C "$SECRETS_DIR" push
    update_lock
    ;;
  update)
    update_lock
    ;;
  *)
    echo "Usage: $0 [edit [file]|update]" >&2
    exit 1
    ;;
esac
