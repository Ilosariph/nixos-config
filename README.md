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
`/etc/nixos/smb-p` and `/etc/nixos/smb-s`
```
username=username
password=password
```

## Hyprpanel weather api
`/etc/nixos/weather.json`
```
{
  "weather_api_key": "123123123"
}
```

