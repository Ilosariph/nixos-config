# Set bootloader settings in {desktop}/machines/{machine}/configuration.nix
So far either
```nix
	boot.loader.grub.enable = true;
	boot.loader.grub.device = "/dev/nvme0n1";
	boot.loader.grub.useOSProber = true;
	boot.kernelPackages = pkgs.linuxPackages_latest;
```
or
```nix
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;
```

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
