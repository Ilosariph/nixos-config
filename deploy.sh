#!/usr/bin/env bash
set -euo pipefail

SIGNING_KEY="/run/secrets/mainpc-nix-signing-key"

usage() {
  echo "Usage: $0 [--safe] <deploy-target> [deploy-rs args...]"
  echo "  e.g. $0 .#evo"
  echo "  --safe  cap build parallelism (--max-jobs 2 --cores 8), for large from-source"
  echo "          builds (onnxruntime, duckdb, ...) that exhaust RAM with the defaults"
  exit 1
}

BUILD_ARGS=()
if [[ "${1:-}" == "--safe" ]]; then
  BUILD_ARGS=(--max-jobs 2 --cores 8)
  shift
fi

[[ $# -eq 0 ]] && usage

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
  "${BUILD_ARGS[@]}" \
  --no-link --print-out-paths)

echo "Signing store paths..."
sudo nix store sign --key-file "$SIGNING_KEY" --recursive "$TOPLEVEL"

echo "Deploying ${TARGET}..."
deploy "$TARGET" "$@"
