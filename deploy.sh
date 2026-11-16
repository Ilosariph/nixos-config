#!/usr/bin/env bash
set -euo pipefail

SIGNING_KEY="/run/secrets/mainpc-nix-signing-key"
GCROOTS=/nix/var/nix/gcroots/deploy

usage() {
  echo "Usage: $0 [--safe] <deploy-target|all> [deploy-rs args...]"
  echo "  e.g. $0 .#evo"
  echo "  all     every deploy-rs node (flake .#deploy.nodes): build all closures"
  echo "          at once, sign, then deploy one host at a time, stop at the first failure"
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

if [[ "$TARGET" == all ]]; then
  FLAKE_URL="."
  NODE_LIST=$(nix eval --raw "${FLAKE_URL}#deploy.nodes" \
    --apply 'n: builtins.concatStringsSep "\n" (builtins.attrNames n)')
  mapfile -t NODES <<< "$NODE_LIST"
  [[ -z "$NODE_LIST" ]] && { echo "No deploy nodes found." >&2; exit 1; }
else
  # Accept either "evo" or ".#evo"
  if [[ "$TARGET" != *#* ]]; then
    TARGET=".#${TARGET}"
  fi
  # .#evo → flake=. node=evo
  FLAKE_URL="${TARGET%%#*}"
  NODES=("${TARGET##*#}")
fi

ATTRS=()
for n in "${NODES[@]}"; do
  ATTRS+=("${FLAKE_URL}#nixosConfigurations.${n}.config.system.build.toplevel")
done

echo "Building closures for: ${NODES[*]}..."
# One nix build for all nodes: shared deps build once, in parallel.
BUILT=$(nix build "${ATTRS[@]}" "${BUILD_ARGS[@]}" --no-link --print-out-paths)
# Map node → toplevel by evaluating each path (build output order isn't a contract).
TOPLEVELS=()
for a in "${ATTRS[@]}"; do
  p=$(nix eval --raw "${a}.outPath")
  grep -qxF "$p" <<< "$BUILT" || { echo "Built paths don't include $p ($a)." >&2; exit 1; }
  TOPLEVELS+=("$p")
done

if [[ -d "$GCROOTS" ]]; then
  for i in "${!NODES[@]}"; do
    ln -sfn "${TOPLEVELS[$i]}" "$GCROOTS/${NODES[$i]}"
  done
fi

echo "Signing store paths..."
sudo nix store sign --key-file "$SIGNING_KEY" --recursive "${TOPLEVELS[@]}"

for n in "${NODES[@]}"; do
  echo "Deploying ${FLAKE_URL}#${n}..."
  if ! deploy "${FLAKE_URL}#${n}" "$@"; then
    echo "Deploy of ${n} failed; stopping (remaining: skipped)." >&2
    exit 1
  fi
done
