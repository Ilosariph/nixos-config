#!/usr/bin/env bash
# Usage: ./secrets.sh [edit <host|shared|file>|update|recipient <host>|rekey|split]
#   edit <target>
#                Pull the private nix-secrets clone, open the target, commit +
#                push if changed, then bump the nix-secrets input in flake.lock.
#                <host> -> hosts/<host>.yaml, shared -> shared.yaml (sops);
#                any other path, e.g. private.nix -> $EDITOR (*.yaml/*.json
#                via sops).
#   update       Only bump the nix-secrets input (secrets changed elsewhere).
#   recipient <host>
#                Print a host's age recipient (its SSH ed25519 host key via
#                ssh-to-age), for nix-secrets/.sops.yaml. "local" = this machine.
#   rekey        After editing .sops.yaml: re-encrypt every sops file to the
#                current recipients (sops updatekeys), commit + push, bump lock.
#   split        One-time: split the old all-hosts secrets.yaml into
#                hosts/<host>.yaml + shared.yaml, using the sopsFile each host's
#                config declares per secret. Needs the per-host rules in
#                .sops.yaml first. Leaves secrets.yaml in place.
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
    TARGET="${2:?usage: $0 edit <host|shared|file>}"
    case "$TARGET" in
      shared)  FILE="shared.yaml" ;;
      */*|*.*) FILE="$TARGET" ;;
      *)       FILE="hosts/$TARGET.yaml" ;;
    esac
    ensure_clone
    mkdir -p "$SECRETS_DIR/$(dirname "$FILE")"
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
  split)
    command -v jq >/dev/null || { echo "needs jq: nix shell nixpkgs#jq" >&2; exit 1; }
    ensure_clone
    cd "$SECRETS_DIR"
    [[ -f secrets.yaml ]] || { echo "no secrets.yaml to split" >&2; exit 1; }
    # Plaintext only ever lives in this process's memory / pipes, never on disk.
    PLAIN=$(sops -d --output-type json secrets.yaml)
    # host -> { secret -> file }, from the sopsFile each declared secret uses.
    MAP=$(nix eval --json "$FLAKE_DIR#nixosConfigurations" --apply '
      cfgs: builtins.mapAttrs (_: c: builtins.mapAttrs (_: s:
        let f = baseNameOf (toString s.sopsFile); in
        if f == "shared.yaml" then f else "hosts/${f}") c.config.sops.secrets) cfgs')
    # file -> [secrets]
    FILES=$(jq -c '[.[] | to_entries[] | {file: .value, key: .key}]
      | group_by(.file) | map({(.[0].file): (map(.key) | unique)}) | add // {}' <<<"$MAP")
    for f in $(jq -r 'keys[]' <<<"$FILES"); do
      want=$(jq -c --arg f "$f" '.[$f]' <<<"$FILES")
      missing=$(jq -r --argjson w "$want" '$w - keys | join(" ")' <<<"$PLAIN")
      [[ -n "$missing" ]] && echo "WARN $f: not in secrets.yaml, add later: $missing"
      if [[ -e "$f" ]]; then echo "skip $f (exists)"; continue; fi
      mkdir -p "$(dirname "$f")"
      jq --argjson w "$want" 'with_entries(select(.key as $k | $w | index($k)))' <<<"$PLAIN" \
        | sops -e --input-type json --output-type yaml --filename-override "$f" /dev/stdin > "$f.tmp"
      mv "$f.tmp" "$f"
      echo "wrote $f: $(jq -r 'join(" ")' <<<"$want")"
    done
    unused=$(jq -r --argjson all "$(jq -c '[.[]] | add // []' <<<"$FILES")" 'keys - $all | join(" ")' <<<"$PLAIN")
    [[ -n "$unused" ]] && echo "Not used by any host (left only in secrets.yaml): $unused"
    commit_push "split secrets.yaml per host"
    update_lock
    ;;
  *)
    echo "Usage: $0 [edit <host|shared|file>|update|recipient <host>|rekey|split]" >&2
    exit 1
    ;;
esac
