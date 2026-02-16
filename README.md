# If grub, set grub device in {desktop}/machines/{machine}/configuration.nix
```nix
	boot.loader.grub.device = "/dev/nvme0n1";
	boot.kernelPackages = pkgs.linuxPackages_latest;
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
