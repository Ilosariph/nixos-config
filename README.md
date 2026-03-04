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

# Ollama (evo)

Ollama runs on `127.0.0.1:11435` internally. nginx proxies port `11434` externally and requires an OpenAI-style Bearer token.

Create `/etc/nixos/secrets/ollama-nginx-auth.conf` with your API key:
```bash
sudo mkdir -p /etc/nixos/secrets
sudo nano /etc/nixos/secrets/ollama-nginx-auth.conf
```
```nginx
map $http_authorization $ollama_auth_ok {
    "Bearer YOUR_API_KEY_HERE" 1;
    default                   0;
}
```
```bash
sudo chmod 600 /etc/nixos/secrets/ollama-nginx-auth.conf
```

Test:
```bash
curl http://localhost:11434/api/tags -H "Authorization: Bearer YOUR_API_KEY_HERE"
```

# Pangolin (evo)
Create `/etc/nixos/secrets/pangolin.env`:
```bash
sudo mkdir -p /etc/nixos/secrets
sudo bash -c 'echo "SERVER_SECRET=$(openssl rand -hex 32)" > /etc/nixos/secrets/pangolin.env'
sudo chmod 600 /etc/nixos/secrets/pangolin.env
```
