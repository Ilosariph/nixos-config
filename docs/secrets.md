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
`${inputs.nix-secrets}/hosts/<dotfiles.sops.host>.yaml`; secrets every host
needs set `sopsFile = config.dotfiles.sops.sharedSecretsFile` (`shared.yaml`).
Machines set `dotfiles.sops.enable` + `dotfiles.sops.host`.

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
./secrets.sh edit evo
#   nix-secrets-deploy-key: |
#     <contents of /tmp/nix-secrets-deploy, indented>
rm /tmp/nix-secrets-deploy /tmp/nix-secrets-deploy.pub
deploy .#evo
```

Scope: the key can read nix-secrets only (sops files, still encrypted, +
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
  # One file per host: only that host + you can decrypt it.
  - path_regex: hosts/mainpc\.yaml$
    key_groups: [{ age: [*yubikey_a, *yubikey_b, *backup, *mainpc] }]
  - path_regex: hosts/laptop\.yaml$
    key_groups: [{ age: [*yubikey_a, *yubikey_b, *backup, *laptop] }]
  - path_regex: hosts/macbook\.yaml$
    key_groups: [{ age: [*yubikey_a, *yubikey_b, *backup, *macbook] }]
  - path_regex: hosts/evo\.yaml$
    key_groups: [{ age: [*yubikey_a, *yubikey_b, *backup, *evo] }]
  - path_regex: hosts/nucserver\.yaml$
    key_groups: [{ age: [*yubikey_a, *yubikey_b, *backup, *nucserver] }]
  - path_regex: hosts/laptopserver\.yaml$
    key_groups: [{ age: [*yubikey_a, *yubikey_b, *backup, *laptopserver] }]
  # Only secrets every host really needs (currently none).
  - path_regex: shared\.yaml$
    key_groups:
      - age: [*yubikey_a, *yubikey_b, *backup,
              *mainpc, *laptop, *macbook, *evo, *nucserver, *laptopserver]
  # Parked secrets no host declares: you only.
  - path_regex: unused\.yaml$
    key_groups: [{ age: [*yubikey_a, *yubikey_b, *backup] }]
```

sops can't scope single keys inside one file, so isolation = one file per
host. A secret two hosts need: copy it into both host files (preferred), or
move it to `shared.yaml` if (nearly) all need it.

`unused.yaml` (you-only) parks sops values no host uses yet;
move one into a host file / `shared.yaml` when a host needs it.

Non-secret values like IPs, domains and public keys don't go in sops at all:
they live in `private.nix`, which every host imports (shared by design).

A host without any secrets needs no file (sops-nix only checks files that
declared secrets use).

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
hosts/<host>.yaml # that host's secrets, sops-encrypted to host + you
unused.yaml     # parked secrets no host uses, encrypted to you only
shared.yaml     # secrets every host needs, encrypted to all hosts + you
private.nix     # private-but-not-secret values, plain Nix, read at eval time
```

## private.nix (eval-time values)

`modules/packages/private/private.nix` imports it into `dotfiles.private`, so
any module can use e.g. `config.dotfiles.private.lan.nas`. Values land in the
world-readable `/nix/store` of each machine — fine for IPs, domains, public
keys, IDs; **never** for passwords/tokens (those stay in sops files).

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
    vikunja = "tasks.example.com";   # evo read-only API proxy for Hermes
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
./secrets.sh edit evo        # pull ~/nix-secrets, sops hosts/evo.yaml,
                             # commit + push, nix flake update nix-secrets
./secrets.sh edit shared     # shared.yaml
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

## History

Secrets used to live in this repo (`secrets/secrets.yaml`), encrypted to one
shared age key (`main`) copied to every host. They moved to nix-secrets, were
split per host (`hosts/<host>.yaml`, `shared.yaml`, `unused.yaml`) and `main`
was dropped as a recipient (2026-10-26).

`main` can still decrypt old commits of nix-secrets and the `secrets/` dir in
this repo's history. If you consider it exposed (on evo its `keys.txt` was mode 644), rotate the
actual values.

Open:
- laptop, nucserver, laptopserver have no recipient/host file yet (commented
  out in `.sops.yaml`). Before reactivating one: add its recipient + rule,
  add it to the `shared.yaml` rule, `./secrets.sh rekey`.
