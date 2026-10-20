# finix (mainpc-finix)

[finix](https://github.com/finix-community/finix) is a NixOS-like distro that
runs [finit](https://github.com/finit-project/finit) as PID 1 instead of
systemd. `mainpc-finix` is a test host: mainpc's `dotfiles.*` options
(`modules/machines/mainpc/options.nix`) built with finix aspects instead of
NixOS ones. The NixOS hosts are unchanged.

## Layout

| Path | What |
| --- | --- |
| `modules/hosts/mainpc-finix.nix` | `finix.lib.finixSystem` → `nixosConfigurations.mainpc-finix` |
| `modules/machines/mainpc-finix/` | finix hardware config (new root by label, shared ESP) + mainpc extras |
| `modules/finix/<aspect>/<aspect>.nix` | finix aspects, exposed as `flake.finixModules.<aspect>` (auto-discovered) |
| `modules/finix/finix-modules.nix` | declares the `flake.finixModules` option |
| `modules/packages/*/_*.nix`, `wofi/config`, `wofi/style.css`, `mic-mute/mic-mute.sh` | shared between NixOS and finix (umbriel/noctalia settings, audio routing, docker-push, ...) |

Inputs: `finix`, `finix-community` (community-modules: steam, gamescope, nh,
hjem noctalia module) and `hjem` (replaces home-manager).

## Differences from NixOS mainpc

- **Init / sessions**: finit + eudev + elogind. finit has no user services, so
  what systemd user units do on NixOS is launched from Umbriel's autostart:
  `start-audio-daemons` (pipewire, pipewire-pulse, wireplumber), noctalia +
  random wallpaper, 1Password, udiskie, openrazer-daemon, StreamController.
- **Home config**: Hjem only links files. home-manager `programs.*` modules
  are written out as plain config files (fish/starship, git, ssh, kitty, mpv,
  yazi, zed, swappy, udiskie, tmux, wofi, nvim, direnv, GTK/cursor, mimeapps).
  Session variables go through `pam_env` (`security.pam.environment`).
- **Boot**: limine (finix has no systemd-boot). It shares the ESP and has a
  "NixOS (systemd-boot)" entry that chainloads the existing NixOS loader.
- **Secrets**: sops-nix needs NixOS/systemd, so `modules/finix/sops` decrypts
  `sops.secrets.*` with `sops --decrypt --extract` in an activation script
  (path/owner/group/mode only).
- **Shares**: finit tasks that mount the CIFS shares once the default route
  exists (no automount).
- **YubiKey**: pam_u2f lines prepended to the sudo / polkit-1 PAM text,
  pcscd as a finit service. No LUKS FIDO2 unlock (needs systemd initrd).
- **deploy**: mainpc-finix can run `deploy` (signing key wired into
  nix-daemon), but finix hosts cannot be deploy-rs targets.

Not ported (evaluation prints a warning when enabled): WiVRn/VR service,
libvirtd, CUPS printing, declarative flatpak apps (`flatpak install` them),
EasyEffects, niri, waybar/mako, VPN import, backup timers, fail2ban,
jellyfin container, pangolin-newt, nix-eval, static IP / Wake-on-LAN.

## Installing next to NixOS

finix recommends its own root partition rather than converting the NixOS
root in place. From the running NixOS on mainpc:

1. Create a partition and format it: `sudo mkfs.ext4 -L finix /dev/<partition>`
2. Mount it and the shared ESP:
   `sudo mount /dev/disk/by-label/finix /mnt && sudo mkdir -p /mnt/boot && sudo mount /dev/disk/by-uuid/403E-F30E /mnt/boot`
3. Install: `sudo nixos-install --flake .#mainpc-finix --root /mnt --no-root-passwd`
   (an `efibootmgr` exit code 8 from limine can be ignored)
4. Set simon's password: `sudo nixos-enter --root /mnt -c 'passwd simon'`
5. Copy the age key for secrets: `/home/simon/.config/sops/age/keys.txt` into
   `/mnt/home/simon/.config/sops/age/` (owned by simon)
6. Reboot; limine is now first in the boot order and lists both systems.

Later rebuilds from inside finix: `./build.sh mainpc-finix nix` (nh) or
`sudo nixos-rebuild switch --flake .#mainpc-finix`.

To go back, pick "NixOS (systemd-boot)" in limine, or move systemd-boot
back to the front of the UEFI boot order with `efibootmgr -o`.
