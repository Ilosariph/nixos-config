#!/usr/bin/env bash
# Usage: ./build.sh [--local-secrets] [flake-name] [nix|boot|test|home|vm] [optional-label]
#   --local-secrets  Build against the nix-secrets clone ($NIX_SECRETS_DIR,
#                    default ~/nix-secrets) as it is on disk, uncommitted edits
#                    included, instead of the locked input. flake.lock untouched.
# Wraps nh (https://github.com/nix-community/nh). nh elevates with sudo itself
# only for the activation step, so do not run this script with sudo.
set -euo pipefail

FLAKE_NAME="mainpc"
MODE="nix"
# Extra nix args, passed after nh's `--`.
NIX_ARGS=()

ARGS=()
for arg in "$@"; do
  if [[ "$arg" == --local-secrets ]]; then
    NIX_ARGS+=(--override-input nix-secrets "path:${NIX_SECRETS_DIR:-$HOME/nix-secrets}")
  else
    ARGS+=("$arg")
  fi
done
set -- "${ARGS[@]}"

# 1. Flake Config Name
if [[ -n "${1:-}" && ! "$1" =~ ^(nix|boot|test|home|vm)$ ]]; then
  FLAKE_NAME="$1"
  shift
fi

# 2. Mode Selection
if [[ -n "${1:-}" && "$1" =~ ^(nix|boot|test|home|vm)$ ]]; then
  MODE="$1"
  shift
fi

LABEL="$*"

# Before the first nh-enabled rebuild, nh isn't installed yet. Fall back to nh
# from this flake's locked nixpkgs (not the system channel, which may be
# missing or too old for this CLI).
if command -v nh >/dev/null 2>&1; then
  NH=(nh)
else
  echo "nh not found, running it from the flake's nixpkgs..."
  NH=(nix --extra-experimental-features "nix-command flakes" run --inputs-from . nixpkgs#nh --)
fi

case "$MODE" in
  nix)  CMD=("${NH[@]}" os switch . -H "$FLAKE_NAME") ;;
  boot) CMD=("${NH[@]}" os boot . -H "$FLAKE_NAME") ;;
  test) CMD=("${NH[@]}" os test . -H "$FLAKE_NAME") ;;
  home) CMD=("${NH[@]}" home switch . -c "$FLAKE_NAME") ;;
  vm)
    echo "Cleaning up previous VM builds..."
    rm -rf ./result
    find . -maxdepth 1 -name "*.qcow2" -delete
    CMD=("${NH[@]}" os build-vm . -H "$FLAKE_NAME")
    ;;
esac

# system.nixos.label reads NIXOS_LABEL via builtins.getEnv, which only sees
# the environment under impure evaluation.
if [[ -n "$LABEL" ]]; then
  export NIXOS_LABEL="$LABEL"
  NIX_ARGS+=(--impure)
fi

if ((${#NIX_ARGS[@]})); then
  CMD+=(-- "${NIX_ARGS[@]}")
fi

echo "${CMD[*]}"
"${CMD[@]}"
