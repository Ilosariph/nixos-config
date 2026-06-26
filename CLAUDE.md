# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Repository Overview

This is a NixOS configuration repository using **flake-parts** + **import-tree** (dendritic pattern). Each feature/program lives in a single file under `modules/packages/<aspect>/` covering both NixOS system config and home-manager config. Auto-discovery via `import-tree` removes manual import wiring.

Desktop systems use the Niri window manager (`dotfiles.windowManager.type`).

## Build Commands

### Building NixOS System Configuration
```bash
# Using the build script (recommended)
./build.sh [flake-name] [nix|home|vm] [optional-label]

# Examples:
./build.sh mainpc nix          # Build and switch NixOS config for mainpc
./build.sh laptop home         # Build and switch home-manager config for laptop
./build.sh mainpc vm           # Build a VM for testing

# Manual commands (from project root):
sudo nixos-rebuild switch --flake .#mainpc
sudo nixos-rebuild switch --flake .#nucserver
```

### Deploying Remote Machines (deploy-rs)

Remote servers (evo, nucserver) are deployed from mainpc using deploy-rs:

```bash
deploy .#evo          # Deploy evo
deploy .#nucserver    # Deploy nucserver
deploy .              # Deploy all enabled nodes
```

To add a machine as a deploy target, set `dotfiles.deploy.enable = true` in its options.nix. The hostname is auto-derived from `dotfiles.network.staticIP` or `dotfiles.network.hostname`; set `dotfiles.deploy.hostname` explicitly if neither is set.

The `deploy` binary is installed on mainpc via `dotfiles.deploy.installTool = true`.

#### Nix Store Signing Key Setup

deploy-rs pushes store paths from mainpc to target machines. Target machines reject unsigned paths by default, so mainpc must sign them with a trusted key.

**One-time setup** (run on mainpc):

```bash
# Generate the signing key pair
sudo nix-store --generate-binary-cache-key mainpc /tmp/signing-key.sec /tmp/signing-key.pub

# Add both to sops secrets
sops secrets/secrets.yaml
# Add:
#   mainpc-nix-signing-key: "<contents of /tmp/signing-key.sec>"
#   mainpc-nix-signing-key-pub: "trusted-public-keys = <contents of /tmp/signing-key.pub>"

# Clean up plain-text key files
rm /tmp/signing-key.sec /tmp/signing-key.pub
```

Note: `mainpc-nix-signing-key-pub` must be in nix.conf format, i.e.:
```
trusted-public-keys = mainpc:base64pubkey=
```

Then rebuild mainpc (loads the signing key) and deploy evo (trusts the public key).

### Available Flake Configurations
- **Desktop**: `mainpc`, `laptop`, `macbook` (aarch64)
- **Servers**: `nucserver`, `laptopserver`, `evo`

## Architecture

### Flake Structure

`flake.nix` uses `flake-parts` as orchestrator:
- `import-tree ./modules/packages` auto-discovers all aspect modules
- `modules/_hosts/*.nix` are explicitly loaded (skipped by import-tree due to `_` prefix)
- Each host file instantiates `nixpkgs.lib.nixosSystem` referencing all `config.flake.nixosModules.*`

### Module Loading Pattern

Each aspect in `modules/packages/<aspect>/<aspect>.nix` is a **flake-parts module** exposing `flake.nixosModules.<aspect>`. It contains both NixOS system config and home-manager config for that feature, guarded by the relevant `dotfiles.*` option.

### Directory Structure

```
.
├── flake.nix                    # flake-parts entry + import-tree
├── options.nix                  # All dotfiles.* option definitions
│
├── modules/
│   ├── _hosts/                  # Host instantiation (explicit, not auto-discovered)
│   │   ├── mainpc.nix
│   │   ├── laptop.nix
│   │   ├── macbook.nix
│   │   ├── nucserver.nix
│   │   ├── laptopserver.nix
│   │   └── evo.nix
│   │
│   ├── _machines/               # Per-machine options + hardware (skipped by import-tree)
│   │   ├── mainpc/
│   │   ├── laptop/
│   │   ├── macbook/
│   │   ├── nucserver/
│   │   ├── laptopserver/
│   │   └── evo/
│   │
│   └── packages/                # Auto-discovered aspect modules
│       ├── base/base.nix            # Locale, users, nix settings, base packages
│       ├── bootloader/bootloader.nix
│       ├── network/network.nix
│       ├── bluetooth/bluetooth.nix
│       ├── vpn/vpn.nix
│       ├── shares/shares.nix
│       ├── ssh/ssh.nix
│       ├── fail2ban/fail2ban.nix
│       ├── docker/docker.nix
│       ├── desktop/desktop.nix      # Desktop system + home-manager config
│       ├── git/git.nix
│       ├── neovim/neovim.nix + nvim/
│       ├── 1password/1password.nix
│       ├── home-base/home-base.nix  # Sets home.username/homeDirectory/stateVersion
│       ├── kitty/kitty.nix
│       ├── fish/fish.nix
│       ├── bash/bash.nix
│       ├── mpv/mpv.nix
│       ├── yazi/yazi.nix
│       ├── zed/zed.nix
│       ├── swappy/swappy.nix
│       ├── udiskie/udiskie.nix
│       ├── orca-slicer/orca-slicer.nix
│       ├── easyeffects/easyeffects.nix
│       ├── niri/niri.nix
│       ├── waybar/waybar.nix        # Waybar + mako
│       ├── wofi/wofi.nix            # Wofi launcher/menu styling (WM/statusbar-independent)
│       ├── noctalia/noctalia.nix
│       └── vr/vr.nix
│
└── shells/                      # Dev shells
```

**Key convention**: `_`-prefixed directories are skipped by import-tree. `_hosts/` and `_machines/` must be loaded explicitly.

### Aspect File Pattern

Every file in `modules/packages/` is a **flake-parts module**:

```nix
{ ... }: {
  flake.nixosModules.<aspect> = { config, lib, pkgs, ... }:
    lib.mkIf config.dotfiles.programs.<aspect>.enable {
      # System config here
      home-manager.users.${config.dotfiles.user.name} = { ... }: {
        # Home-manager config here
      };
    };
}
```

### Custom Options System

Machine-specific settings are defined via custom `dotfiles.*` options in `options.nix`:

- **`dotfiles.desktop.enable`**: Enable desktop environment (audio, printing, flatpak, GUI programs, WM)
- **`dotfiles.windowManager.type`**: `"niri"` (the only supported window manager)
- **`dotfiles.windowManager.*`**: Monitor layouts, statusbar, keybindings (QWERTY/Colemak), mouse settings
- **`dotfiles.services.ssh.enable`**: Enable OpenSSH (server machines)
- **`dotfiles.services.fail2ban.enable`**: Enable fail2ban (server machines)
- **`dotfiles.programs.*`**: Per-program enable flags
  - Shell: `fish`, `bash`, `tmux` (default true)
  - Utilities: `udiskie` (default `desktop.enable`)
  - Specialized: `vr`, `steam`, `thonny`, `blog`, `yeetmouse` (default false)
  - Desktop GUI programs (kitty, mpv, yazi, zed, swappy, orca-slicer) have no per-program flag — they install whenever `desktop.enable` is set (yazi installs everywhere, it's a TUI)
- **`dotfiles.vpn`**: Enable/disable, WireGuard account list
- **`dotfiles.bluetooth.enable`**
- **`dotfiles.bootloader`**: `"systemd"` (default) or `"grub"`
- **`dotfiles.network`**: hostname, interface, staticIP, gateway, nameservers

### Adding a New Machine

1. Create `modules/_machines/{machine-name}/` with:
   - `options.nix` - Set `dotfiles.*` options
   - `configuration.nix` - NixOS system config
   - `hardware-configuration.nix` - Hardware config
   - `home.nix` - Home-manager config
2. Create `modules/_hosts/{machine-name}.nix` instantiating `nixpkgs.lib.nixosSystem` with all shared `config.flake.nixosModules.*`
3. Add the host file to the explicit imports in `flake.nix`

### Adding a New Aspect/Program

1. Create `modules/packages/<aspect>/<aspect>.nix` as a flake-parts module
2. Optionally add a `dotfiles.programs.<aspect>.enable` option in `options.nix`
3. No changes needed to `flake.nix` — import-tree auto-discovers it

### Secrets Management

Uses `sops-nix` with age encryption. All secrets live in the `secrets/` folder:
- `secrets/.sops.yaml` — sops config (age key, path rules)
- `secrets/secrets.yaml` — general secrets (SSH keys, signing keys, VPN, etc.)

Age keys must be placed at `/home/simon/.config/sops/age/keys.txt`.

## Special Machines

### Macbook (Apple Silicon)
- Uses `aarch64-linux` architecture
- Has custom `apple-silicon-support` submodule in `modules/_machines/macbook/`
- Requires manual WireGuard configuration files

### Mainpc
- Includes VR support via `nixpkgs-xr` (`dotfiles.programs.vr.enable = true`)
- Gaming configuration with Steam in `modules/_machines/mainpc/gaming/`

## Window Manager Configuration

### Niri
- Aspect file: `modules/packages/niri/niri.nix`
- Self-guarded: only activates when `dotfiles.windowManager.type == "niri"`
- Config generated from `dotfiles.windowManager` options
- See `SHORTCUTS.md` for the full keybinding list

### Status Bars & Notifications
- Waybar + mako: `modules/packages/waybar/waybar.nix` (guarded by `statusbar == "waybar"`)
- Wofi launcher/menu styling: `modules/packages/wofi/wofi.nix` (guarded by `desktop.enable`, so it applies under any statusbar — used by the launcher and the audio-output switcher)
- Noctalia: `modules/packages/noctalia/noctalia.nix` (guarded by `statusbar == "noctalia"`)
