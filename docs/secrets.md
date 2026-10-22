# Secrets (private nix-secrets repo)

sops-encrypted secrets live in a separate private repo,
`Ilosariph/nix-secrets`, so this config repo can be public without even the
encrypted blobs in it. It's consumed as a non-flake input:

```nix
nix-secrets = {
  url = "git+ssh://git@github.com/Ilosariph/nix-secrets.git?ref=main&shallow=1";
  flake = false;
};
```

`modules/packages/sops/sops.nix` points `sops.defaultSopsFile` at
`${inputs.nix-secrets}/secrets.yaml`. Machines only need `dotfiles.sops.enable`.

## Auth: SSH instead of a GitHub PAT

Fetching a private repo via `github:` needs `access-tokens = github.com=<PAT>`
in nix.conf — a token that expires, has to be rotated and is itself a secret
to manage. `git+ssh://` instead makes Nix shell out to `git`, which uses the
normal SSH setup of the user running the evaluation:

- `nh` / `./build.sh` evaluate as your user (sudo only for activation) →
  your SSH key / 1Password SSH agent is used. Same for `deploy` from mainpc.
- Requirement: an SSH key on your GitHub account, usable on each machine that
  evaluates the flake (mainpc, laptop, macbook). Servers deployed from mainpc
  never fetch it themselves.
- Never `sudo nixos-rebuild` — root has no GitHub SSH key.
- Optional, for a headless machine that builds itself: add a read-only
  **deploy key** to the nix-secrets repo instead of your personal key.

### evo nix-eval service (deploy key)

evo's `nix-eval` service (Hermes' eval/build endpoint) evaluates the flake on
evo as a systemd `DynamicUser` — no personal SSH key there. It fetches
nix-secrets with a dedicated **read-only deploy key** instead:

- sops secret `nix-secrets-deploy-key` (private key) → handed to the service
  via `LoadCredential`, used through `GIT_SSH_COMMAND`.
- GitHub's ed25519 host key pinned in `programs.ssh.knownHosts`.

One-time setup:

```bash
ssh-keygen -t ed25519 -N "" -C "evo nix-eval (read-only)" -f /tmp/nix-secrets-deploy
# GitHub → Ilosariph/nix-secrets → Settings → Deploy keys → Add deploy key:
#   paste /tmp/nix-secrets-deploy.pub, leave "Allow write access" UNCHECKED
./secrets.sh edit
#   nix-secrets-deploy-key: |
#     <contents of /tmp/nix-secrets-deploy, indented>
rm /tmp/nix-secrets-deploy /tmp/nix-secrets-deploy.pub
deploy .#evo
```

Scope: the key can read nix-secrets only (encrypted `secrets.yaml` +
`private.nix`). Hermes-edited code is evaluated in pure mode, so it can't read
the credential file directly; builds run in the nix sandbox.

Fetched content is stored in `/nix/store` like any input. Still encrypted,
decrypted only at activation (see Keys below).

## Keys

sops encrypts one data key per recipient; **any one** recipient can decrypt.

| Recipient | Used for | Where the private key lives |
|---|---|---|
| Host SSH key (`ssh-to-age` of `/etc/ssh/ssh_host_ed25519_key.pub`) | Decrypt at activation | `/etc/ssh/ssh_host_ed25519_key` on that host |
| YubiKey A / B (`age1yubikey1…`) | You editing (PIN + touch) | PIV slot, never leaves the key |
| Backup age key (`age1…`) | Recovery if all YubiKeys are lost | Offline (paper / safe), **not** on disk |

- `modules/packages/sops/sops.nix` sets `sops.age.sshKeyPaths` to the ed25519
  host key and creates it at activation if missing (desktops don't run sshd).
- `~/.config/sops/age/keys.txt` on editing machines holds only YubiKey
  identity **stubs** (`AGE-PLUGIN-YUBIKEY-…`, not secret); sops finds them
  there and calls `age-plugin-yubikey` (installed by the yubikey module, needs
  `pcscd`). Enable `dotfiles.security.yubikey` on any machine you edit from.
- Don't point `dotfiles.sops.ageKeyFile` at that file: activation can't touch
  a YubiKey. It's an optional fallback for a real age key only (default null).

### `.sops.yaml` (in nix-secrets)

```yaml
keys:
  # you (editing)
  - &yubikey_a age1yubikey1q...
  - &yubikey_b age1yubikey1q...
  - &backup    age1...
  # hosts (./secrets.sh recipient <host>)
  - &mainpc       age1...
  - &laptop       age1...
  - &macbook      age1...
  - &evo          age1...
  - &nucserver    age1...
  - &laptopserver age1...
creation_rules:
  - path_regex: .*\.yaml$
    key_groups:
      - age:
          - *yubikey_a
          - *yubikey_b
          - *backup
          - *mainpc
          - *laptop
          - *macbook
          - *evo
          - *nucserver
          - *laptopserver
```

After any change: `./secrets.sh rekey` (runs `sops updatekeys` on every file,
needs one of your keys), then rebuild/deploy.

### YubiKey setup (per key)

```bash
age-plugin-yubikey            # interactive: pick slot, PIN policy, touch=always
age-plugin-yubikey --list     # → recipient age1yubikey1… for .sops.yaml
age-plugin-yubikey --identity >> ~/.config/sops/age/keys.txt   # stub
```

Repeat with the spare key. Copy `keys.txt` (stubs only) to other machines you
edit from.

### Reinstalled host / new machine

A fresh install has a new host key → old recipient useless → that host can't
decrypt until re-keyed (it boots; services needing secrets fail).

```bash
./secrets.sh recipient evo       # or `local` on the machine itself
# replace evo's entry in ~/nix-secrets/.sops.yaml
./secrets.sh rekey
deploy .#evo                     # or ./build.sh <host>
```

To skip re-keying, back up the host key and restore it before the first
rebuild (e.g. `nixos-anywhere --extra-files`). New machine: generate the key
first (`ssh-keygen -t ed25519 -N "" -f /etc/ssh/ssh_host_ed25519_key`), add
its recipient, rekey, then install.

## Repo layout (nix-secrets)

```
.sops.yaml      # age recipients + creation rules
secrets.yaml    # real secrets, sops-encrypted, decrypted at activation
private.nix     # private-but-not-secret values, plain Nix, read at eval time
```

## private.nix (eval-time values)

`modules/packages/private/private.nix` imports it into `dotfiles.private`, so
any module can use e.g. `config.dotfiles.private.lan.nas`. Values land in the
world-readable `/nix/store` of each machine — fine for IPs, domains, public
keys, IDs; **never** for passwords/tokens (those stay in `secrets.yaml`).

Expected shape (all keys used by this repo):

```nix
{
  lan = {
    subnet = "192.168.1.0/24";   # fail2ban ignoreIP
    gateway = "192.168.1.1";
    nas = "192.168.1.10";        # default SMB server + DNS
    nasV6 = "fd00::1";           # DNS
    scanner = "192.168.1.20";    # mainpc ScansLaserjet share
  };
  hosts.evo = "192.168.1.30";    # static IP (deploy-rs target)
  domains = {
    jellyfin = "jellyfin.example.com";
    pangolin = "pangolin.example.com";
  };
  ssh.authorizedKeys = [ "ssh-ed25519 AAAA... simon@mainpc" ];  # servers
  nix.mainpcSigningPublicKey = "mainpc:base64=";               # evo trusts it
  hermes = {
    discordAllowedUsers = "123,456";
    discordChannel = "789";
    dashboardUsername = "simon";
  };
}
```

A missing key fails evaluation with `attribute '<name>' missing` — add it to
`private.nix` and `./secrets.sh update`.

Edit with `./secrets.sh edit private.nix`: same pull/commit/push/lock flow,
but opens the plain file in `$EDITOR` instead of sops.

## Day-to-day

```bash
./secrets.sh edit            # pull ~/nix-secrets, sops secrets.yaml,
                             # commit + push, nix flake update nix-secrets
./secrets.sh edit private.nix # eval-time values, plain $EDITOR
./secrets.sh update          # secrets pushed from another machine → bump lock
```

Then commit `flake.lock` and rebuild/deploy. The lock pins a secrets commit, so
a machine only sees new secrets once the bumped lock reaches it.

Clone location: `$NIX_SECRETS_DIR` (default `~/nix-secrets`).

### Testing unpushed secrets

```bash
nh os test . -H mainpc -- --override-input nix-secrets path:$HOME/nix-secrets
```

## One-time migration

1. Create an **empty private** GitHub repo `Ilosariph/nix-secrets`.
2. Seed it from this repo's old `secrets/` dir (history keeps it, so this works
   even after step 5):
   ```bash
   git clone git@github.com:Ilosariph/nix-secrets.git ~/nix-secrets
   cd ~/nixos-config
   git show 1a035e3:secrets/secrets.yaml > ~/nix-secrets/secrets.yaml
   git show 1a035e3:secrets/.sops.yaml   > ~/nix-secrets/.sops.yaml
   cd ~/nix-secrets && git add -A && git commit -m "initial secrets" && git push -u origin main
   ```
3. Create `~/nix-secrets/private.nix` (shape above). Values that used to be
   sops secrets can be read out with e.g.
   `sops -d --extract '["hermes-discord-channel"]' ~/nix-secrets/secrets.yaml`:
   `nucserver-ssh-public-key` → `ssh.authorizedKeys`,
   `mainpc-nix-signing-key-pub` (without `trusted-public-keys = `) →
   `nix.mainpcSigningPublicKey`, `hermes-discord-allowed-users`,
   `hermes-discord-channel`, `hermes-dashboard-username` → `hermes.*`.
   Then drop those 5 keys from `secrets.yaml` (unused now), commit, push.
4. Lock the input and verify decryption still works:
   ```bash
   cd ~/nixos-config
   nix flake lock            # adds nix-secrets to flake.lock
   sops -d ~/nix-secrets/secrets.yaml >/dev/null && echo ok
   ./build.sh mainpc test
   ```
5. Remove the old copy and commit:
   ```bash
   git rm -r secrets && git commit -am "secrets: move to private nix-secrets repo"
   ```

## Switching from the shared age key to host keys + YubiKey

Old setup: one age key (`&main`) copied to every host's `keys.txt`. Do this
**before** deploying the sops.nix change, otherwise hosts can't decrypt.

1. YubiKeys: `nix shell nixpkgs#age-plugin-yubikey`, then the YubiKey setup
   above for each key. Keep the stubs in a **separate file** for now
   (`~/.config/sops/age/yubikey.txt`), since `keys.txt` still holds `main`.
2. Backup key: `age-keygen -o backup.txt` → note the recipient, store the
   file offline, delete it from disk.
3. Host recipients:
   - Servers (sshd already has a key): `./secrets.sh recipient <ip>`.
   - Desktops (no sshd): on each,
     `sudo ssh-keygen -t ed25519 -N "" -f /etc/ssh/ssh_host_ed25519_key`
     then `./secrets.sh recipient local` (needs `nix shell nixpkgs#ssh-to-age`
     until the next rebuild).
4. `.sops.yaml`: add all of the above, **keep `&main` for now**.
   `./secrets.sh rekey` (decrypts with `main`).
5. Merge the branch, rebuild desktops, `deploy` servers. Check
   `ls /run/secrets/` on each.
6. Drop `&main` from `.sops.yaml`, `./secrets.sh rekey` (now via YubiKey:
   `SOPS_AGE_KEY_FILE=~/.config/sops/age/yubikey.txt ./secrets.sh rekey`).
7. Replace `keys.txt` with the stubs on editing machines
   (`mv yubikey.txt keys.txt`), delete it on servers.

`main` can still decrypt old commits of nix-secrets (and of this repo's
history). If you consider it exposed, rotate the actual secret values.

Note: the encrypted `secrets/` stays in this repo's git history. Fine as long
as the age key is safe; if the repo goes public and that's a concern, rotate
the secrets (or rewrite history).
