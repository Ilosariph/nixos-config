# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Repository Overview

This is a NixOS configuration repository using **flake-parts** + **import-tree** (dendritic pattern). Each feature/program lives in a single file under `modules/packages/<aspect>/` covering both NixOS system config and home-manager config. Auto-discovery via `import-tree` removes manual import wiring.

Desktop systems use the Niri window manager by default; Umbriel is an alternative (`dotfiles.windowManager.type`).

## Build Commands

### Building NixOS System Configuration
```bash
# Using the build script (recommended)
./build.sh [flake-name] [nix|boot|test|home|vm] [optional-label]

# Examples:
./build.sh mainpc nix          # Build and switch NixOS config for mainpc
./build.sh mainpc boot         # Build, activate on next boot
./build.sh laptop home         # Build and switch home-manager config for laptop
./build.sh mainpc vm           # Build a VM for testing

# Manual commands (from project root, no sudo — nh elevates itself):
nh os switch . -H mainpc
nh os switch . -H nucserver -a   # show diff, ask before activating
```

`build.sh` wraps [nh](https://github.com/nix-community/nh) (enabled on all hosts by `modules/packages/nh/nh.nix`, incl. weekly `nh clean`). See `docs/nh.md`.

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

# Private key → sops secrets (private nix-secrets repo)
./secrets.sh edit
# Add:
#   mainpc-nix-signing-key: "<contents of /tmp/signing-key.sec>"

# Public key → eval-time private.nix (not secret)
./secrets.sh edit private.nix
# Set:
#   nix.mainpcSigningPublicKey = "<contents of /tmp/signing-key.pub>";   # mainpc:base64=

# Clean up plain-text key files
rm /tmp/signing-key.sec /tmp/signing-key.pub
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
│       ├── nh/nh.nix                # nh CLI helper + weekly GC
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
│       ├── plezy/plezy.nix          # Plex/Jellyfin/Emby client
│       ├── orca-slicer/orca-slicer.nix
│       ├── easyeffects/easyeffects.nix
│       ├── niri/niri.nix
│       ├── umbriel/umbriel.nix      # Umbriel compositor (niri alternative)
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
- **`dotfiles.windowManager.type`**: `"niri"` (default) or `"umbriel"`
- **`dotfiles.windowManager.*`**: Monitor layouts, statusbar, keybindings (QWERTY/Colemak), mouse settings
- **`dotfiles.services.ssh.enable`**: Enable OpenSSH (server machines)
- **`dotfiles.services.fail2ban.enable`**: Enable fail2ban (server machines)
- **`dotfiles.programs.*`**: Per-program enable flags
  - Shell: `fish`, `bash`, `tmux` (default true)
  - Utilities: `udiskie`, `plezy` (default `desktop.enable`)
  - Specialized: `vr`, `steam`, `thonny`, `blog`, `yeetmouse`, `gnirehtet` (default false)
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

Uses `sops-nix` with age encryption. Secrets live in the private repo `Ilosariph/nix-secrets`, consumed as the non-flake input `nix-secrets` (fetched via `git+ssh`, so the user's SSH key/agent authenticates — no PAT). `modules/packages/sops/sops.nix` defaults `dotfiles.sops.defaultSecretsFile` to `${inputs.nix-secrets}/secrets.yaml`. Repo layout:
- `.sops.yaml` — sops config (recipients: YubiKeys, backup key, host keys)
- `secrets.yaml` — general secrets (SSH keys, signing keys, VPN, etc.)

`private.nix` in the same repo holds private-but-not-secret values (LAN IPs, domains, public keys, Discord IDs), imported at eval time into `config.dotfiles.private` by `modules/packages/private/private.nix`. They land in the nix store, so never put passwords/tokens there. Use `config.dotfiles.private.*` instead of hard-coding IPs/domains in this public repo.

Edit secrets with `./secrets.sh edit` (pulls clone at `~/nix-secrets`, runs sops, commits + pushes, bumps `flake.lock`). Secrets changed elsewhere → `./secrets.sh update`. See `docs/secrets.md`.

Keys: hosts decrypt with their SSH host key `/etc/ssh/ssh_host_ed25519_key` (`sops.age.sshKeyPaths`; generated at activation if missing, e.g. desktops without sshd). Editing uses YubiKeys via `age-plugin-yubikey` (identity stubs in `~/.config/sops/age/keys.txt`), plus an offline backup age key. Recipients are in `nix-secrets/.sops.yaml`; `./secrets.sh recipient <host>` prints a host's recipient, `./secrets.sh rekey` re-encrypts after changing them. A reinstalled host has a new host key → re-key (see `docs/secrets.md`).

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

### Umbriel
- Aspect file: `modules/packages/umbriel/umbriel.nix`
- Self-guarded: only activates when `dotfiles.windowManager.type == "umbriel"`
- Uses nixpkgs `programs.umbriel` (session for greetd, xdg-desktop-portal-umbriel); Xwayland started on demand by Umbriel itself
- `~/.config/umbriel/config.toml` generated from the same `dotfiles.windowManager` options as niri (monitors, keys, execOnce, window rules); "tools" is a scratchpad (StreamController opens hidden there, `Mod+F1` toggles, like Hyprland's old `special:tools`); keybinds mirror niri's
- Waybar uses `ext/workspaces` under Umbriel instead of `niri/workspaces`
- Validate generated config: `umbriel validate`

### Status Bars & Notifications
- Waybar + mako: `modules/packages/waybar/waybar.nix` (guarded by `statusbar == "waybar"`)
- Wofi launcher/menu styling: `modules/packages/wofi/wofi.nix` (guarded by `desktop.enable`, so it applies under any statusbar — used by the launcher and the audio-output switcher)
- Noctalia: `modules/packages/noctalia/noctalia.nix` (guarded by `statusbar == "noctalia"`)
