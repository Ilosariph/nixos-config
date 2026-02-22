# Hyprland Shortcuts

See [HYPRLAND_SHORTCUTS.md](./HYPRLAND_SHORTCUTS.md) for a full list of keybindings.

---

# If grub, set grub device in {desktop}/machines/{machine}/options.nix
```nix
  dotfiles.bootloader = "grub";
  dotfiles.grubDevice = "/dev/nvme0n1";
```

# For macbook
Put wireguard conf into `/etc/wireguard/home.conf` and `/etc/wireguard/proton.conf`

# Build nixos config
From project root:
```bash
sudo nixos-rebuild switch --flake .#simon
```

# Build home-manager config
From project root:
```bash
home-manager switch --flake .#simon
```

# Create cred files:
## SMB
`/etc/nixos/smb-p`, `/etc/nixos/smb-s` and `/etc/nixos/smb-scan`
```
username=username
password=password
```
# Key file for sops
`/home/simon/.config/sops/age/keys.txt`
```
SECRET-KEY
```
