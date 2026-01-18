#!/usr/bin/env bash

FLAKE_NAME="hyprland-mainpc"
BUILD_CMD="nixos-rebuild"
ACTION="switch"
USE_SUDO=true
LABEL=""

# 1. Flake Config Name
if [[ -n "$1" && "$1" != "nix" && "$1" != "home" && "$1" != "vm" ]]; then
  FLAKE_NAME="$1"
  shift
fi

# 2. Mode Selection
case "$1" in
  nix)
    BUILD_CMD="nixos-rebuild"
    ACTION="switch"
    USE_SUDO=true
    shift
    ;;
  home)
    BUILD_CMD="home-manager"
    ACTION="switch"
    USE_SUDO=false
    shift
    ;;
  vm)
    BUILD_CMD="nixos-rebuild"
    ACTION="build-vm"
    USE_SUDO=true
    shift
    ;;
esac

LABEL="$*"

# --- Command Execution ---

# Note: We pass NIXOS_LABEL directly inside sudo to ensure it isn't scrubbed 
# by the security policy.
if [[ "$USE_SUDO" == true ]]; then
    sudo NIXOS_LABEL="$LABEL" "$BUILD_CMD" "$ACTION" "--flake" ".#$FLAKE_NAME"
else
    NIXOS_LABEL="$LABEL" "$BUILD_CMD" "$ACTION" "--flake" ".#$FLAKE_NAME"
fi
