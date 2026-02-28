# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Repository Overview

This is a NixOS configuration repository using flakes and home-manager. It manages configurations for multiple machines across two categories: desktop systems (`with-desktop`) and server systems (`no-desktop`). Desktop systems support both Hyprland and Niri window managers.

## Build Commands

### Building NixOS System Configuration
```bash
# Using the build script (recommended)
./build.sh [flake-name] [nix|home|vm] [optional-label]

# Examples:
./build.sh hyprland-mainpc nix          # Build and switch NixOS config for mainpc
./build.sh hyprland-laptop home         # Build and switch home-manager config for laptop
./build.sh hyprland-mainpc vm           # Build a VM for testing

# Manual commands (from project root):
sudo nixos-rebuild switch --flake .#hyprland-mainpc
sudo nixos-rebuild switch --flake .#niri-mainpc
sudo nixos-rebuild switch --flake .#nucserver
```

### Building Home Manager Configuration
```bash
home-manager switch --flake .#simon
```

### Available Flake Configurations
- **Desktop (Hyprland)**: `hyprland-mainpc`, `hyprland-laptop`, `hyprland-macbook` (aarch64)
- **Desktop (Niri)**: `niri-mainpc`
- **Servers**: `nucserver`, `laptopserver`

## Architecture

### Flake Structure

The `flake.nix` uses a `nixos-conf` function that combines modules based on three parameters:
- `desktop`: Either `with-desktop` or `no-desktop`
- `pc`: Machine name (e.g., `mainpc`, `laptop`, `nucserver`)
- `windowManager`: Either `hyprland` or `niri` (only for desktop systems)

### Module Loading Pattern

NixOS configuration is assembled from:
1. **Options**: `options.nix` + `{desktop}/machines/{pc}/options.nix`
2. **System config**:
   - `general/config/configuration.nix` (base system config)
   - `{desktop}/config/configuration.nix` (desktop/server-specific)
   - `{desktop}/{windowManager}/configuration.nix` (WM-specific, if desktop)
   - `{desktop}/machines/{pc}/configuration.nix` (machine-specific)
   - `{desktop}/machines/{pc}/hardware-configuration.nix`
3. **Home-manager config**:
   - `general/home/home.nix` (base home config)
   - `{desktop}/home/home.nix` (desktop/server-specific)
   - `{desktop}/{windowManager}/home.nix` (WM-specific, if desktop)
   - `{desktop}/machines/{pc}/home.nix` (machine-specific)

### Directory Structure

```
.
├── general/          # Shared across all machines
│   ├── bootloader/   # Bootloader configs (systemd/grub)
│   ├── config/       # Base system configuration
│   └── home/         # Base home-manager configuration
├── with-desktop/     # Desktop machine configs
│   ├── config/       # Desktop system configs (audio, printing, etc.)
│   ├── home/         # Desktop home configs and programs
│   ├── hyprland/     # Hyprland window manager configs
│   ├── niri/         # Niri window manager configs
│   └── machines/     # Per-machine configs (mainpc, laptop, macbook)
├── no-desktop/       # Server machine configs
│   ├── config/       # Server-specific configs (SSH, fail2ban)
│   └── machines/     # Per-machine configs (nucserver, laptopserver)
└── shells/           # Development shells
```

### Custom Options System

Machine-specific settings are defined via custom `dotfiles.*` options in `options.nix`:
- **Hyprland**: Monitor layouts, keybindings (QWERTY/Colemak), mouse sensitivity, exec-once commands
- **VPN**: Enable/disable, WireGuard account list
- **Bootloader**: Choose systemd or grub, grub device

Example from `with-desktop/machines/mainpc/options.nix`:
```nix
dotfiles.hyprland.mainMonitor = "DP-3";
dotfiles.hyprland.keyboardLayout = "colemak";
dotfiles.bootloader = "grub";
dotfiles.grubDevice = "/dev/nvme0n1";
```

### Secrets Management

Uses `sops-nix` with age encryption. Configuration is in `.sops.yaml`. Age keys must be placed at `/home/simon/.config/sops/age/keys.txt`.

## Machine-Specific Configurations

### Adding a New Machine

1. Create machine directory: `{desktop}/machines/{machine-name}/`
2. Add required files:
   - `options.nix` - Set `dotfiles.*` options
   - `configuration.nix` - NixOS system config
   - `hardware-configuration.nix` - Hardware config (generate with `nixos-generate-config`)
   - `home.nix` - Home-manager config
3. Add flake entry in `flake.nix` under `nixosConfigurations`

### Desktop Programs

Desktop environment programs are in `with-desktop/home/programs/`:
- Terminal: `kitty.nix`, `fish.nix`, `bash.nix`
- Editor: `zed.nix`
- Notifications: `mako.nix`
- Application launcher: `wofi.nix`
- Status bar: `waybar.nix`
- Media: `mpv.nix`, `yazi.nix`
- Audio: `easyeffects/` (with presets)
- VR: `wlx-overlay-s.nix`

## Required Manual Setup

Some configurations require manual file creation:

1. **SMB Credentials** (for network shares):
   - `/etc/nixos/smb-p`, `/etc/nixos/smb-s`, `/etc/nixos/smb-scan`
   - Format: `username=...\npassword=...`

2. **WireGuard VPN** (macbook):
   - `/etc/wireguard/home.conf`, `/etc/wireguard/proton.conf`

3. **Sops Age Key**:
   - `/home/simon/.config/sops/age/keys.txt`

## Special Machines

### Macbook (Apple Silicon)
- Uses `aarch64-linux` architecture
- Has custom `apple-silicon-support` module with M1N1 bootloader, kernel, and peripheral firmware
- Requires manual WireGuard configuration files

### Mainpc
- Includes VR support via `nixpkgs-xr`
- Gaming configuration with Steam in `gaming/` subdirectory
- Custom mouse acceleration profile for gaming
- Colemak keyboard layout with vim-style directional keys

## Window Manager Configurations

### Hyprland
- Configs in `with-desktop/hyprland/hypr/`: `hyprland.nix`, `hyprlock.nix`, `hypridle.nix`, `hyprpaper/`
- Per-machine monitor, workspace, and keybinding customization via `dotfiles.hyprland.*` options
- See `HYPRLAND_SHORTCUTS.md` for full keybinding list

### Niri
- Configs in `with-desktop/niri/`
- Alternative tiling compositor option
