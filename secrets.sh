#!/usr/bin/env bash
# Usage: ./secrets.sh [edit [file]|update|recipient <host>|rekey]
#   edit [file]  Pull the private nix-secrets clone, open <file> (default
#                secrets.yaml) in sops (*.yaml/*.json) or $EDITOR (anything
#                else, e.g. private.nix), commit + push if changed, then bump
#                the nix-secrets input in flake.lock.
#   update       Only bump the nix-secrets input (secrets changed elsewhere).
#   recipient <host>
#                Print a host's age recipient (its SSH ed25519 host key via
#                ssh-to-age), for nix-secrets/.sops.yaml. "local" = this machine.
#   rekey        After editing .sops.yaml: re-encrypt every sops file to the
#                current recipients (sops updatekeys), commit + push, bump lock.
# Clone location: $NIX_SECRETS_DIR (default ~/nix-secrets). See docs/secrets.md.
set -euo pipefail

REPO="git@github.com:Ilosariph/nix-secrets.git"
SECRETS_DIR="${NIX_SECRETS_DIR:-$HOME/nix-secrets}"
FLAKE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MODE="${1:-edit}"

ensure_clone() {
  if [[ ! -d "$SECRETS_DIR/.git" ]]; then
    git clone "$REPO" "$SECRETS_DIR"
  fi
  git -C "$SECRETS_DIR" pull --ff-only
}

commit_push() {
  if [[ -z "$(git -C "$SECRETS_DIR" status --porcelain)" ]]; then
    echo "No changes."
    exit 0
  fi
  git -C "$SECRETS_DIR" add -A
  git -C "$SECRETS_DIR" commit -m "$1"
  git -C "$SECRETS_DIR" push
}

update_lock() {
  nix flake update nix-secrets --flake "$FLAKE_DIR"
  echo "flake.lock updated. Commit it, then ./build.sh / deploy as usual."
}

case "$MODE" in
  edit)
    FILE="${2:-secrets.yaml}"
    ensure_clone
    # Run from inside the clone so sops picks up its .sops.yaml.
    case "$FILE" in
      *.yaml|*.json) (cd "$SECRETS_DIR" && sops "$FILE") ;;
      *)             (cd "$SECRETS_DIR" && "${EDITOR:-nano}" "$FILE") ;;
    esac
    commit_push "update $FILE"
    update_lock
    ;;
  recipient)
    HOST="${2:?usage: $0 recipient <host|local>}"
    if [[ "$HOST" == local ]]; then
      ssh-to-age < /etc/ssh/ssh_host_ed25519_key.pub
    else
      ssh-keyscan -t ed25519 "$HOST" 2>/dev/null | cut -d" " -f2- | ssh-to-age
    fi
    ;;
  rekey)
    ensure_clone
    (cd "$SECRETS_DIR" && for f in $(git ls-files '*.yaml' ':!.sops.yaml'); do sops updatekeys -y "$f"; done)
    commit_push "rekey to current recipients"
    update_lock
    ;;
  update)
    update_lock
    ;;
  *)
    echo "Usage: $0 [edit [file]|update|recipient <host>|rekey]" >&2
    exit 1
    ;;
esac
