#!/usr/bin/env bash
set -euo pipefail

SIGNING_KEY="/run/secrets/mainpc-nix-signing-key"

if [[ $# -eq 0 ]]; then
  echo "Usage: $0 <deploy-target> [deploy-rs args...]"
  echo "  e.g. $0 .#evo"
  exit 1
fi

TARGET="$1"
shift

# Accept either "evo" or ".#evo"
if [[ "$TARGET" != *#* ]]; then
  TARGET=".#${TARGET}"
fi

# Extract flake ref for building the nixos config
# .#evo → flake=. attr=evo
FLAKE_URL="${TARGET%%#*}"    # .
FLAKE_PART="${TARGET##*#}"   # evo

echo "Building closure for ${TARGET}..."
TOPLEVEL=$(nix build "${FLAKE_URL}#nixosConfigurations.${FLAKE_PART}.config.system.build.toplevel" \
  --no-link --print-out-paths)

echo "Signing store paths..."
sudo nix store sign --key-file "$SIGNING_KEY" --recursive "$TOPLEVEL"

echo "Deploying ${TARGET}..."
deploy "$TARGET" "$@"
