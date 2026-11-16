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
./deploy.sh .#evo
```

Scope: the key can read nix-secrets only (sops files, still encrypted, +
`private.nix`). Hermes-edited code is evaluated in pure mode, so it can't read
the credential file directly; builds run in the nix sandbox.

Fetched content is stored in `/nix/store` like any input. Still encrypted,
decrypted only at activation (see Keys below).

## Keys

sops encrypts one data key per recipient; **any one** recipient can decrypt.
So a file is only post-quantum (PQ) safe once **every** recipient on it is PQ:
the data is AES-256-GCM (fine), but X25519 / P-256 key wrapping falls to Shor,
and a copy of the repo taken today could be decrypted later.

| Recipient | Used for | Where the private key lives |
|---|---|---|
| Host PQ key (`age1pq1…`, `age-keygen -pq`) | Decrypt at activation | `/var/lib/sops-nix/key.txt` on that host (recipient in `key.pub`) |
| Editor PQ key (`age1pq1…`) | You editing | `~/.config/sops/age/editor-pq.age`, encrypted to both YubiKeys |
| Backup PQ key (`age1pq1…`) | Recovery if all YubiKeys are lost | Offline (paper / safe), **not** on disk |

- `modules/packages/sops/sops.nix` generates the host PQ key at activation if
  missing (`dotfiles.sops.ageKeyFile`, default `/var/lib/sops-nix/key.txt`,
  0600) and writes its recipient to `key.pub` (0644). The SSH host key is
  not a sops identity (classical X25519).
- YubiKeys (`age-plugin-yubikey`, P-256 PIV) can't do ML-KEM, so the PQ
  editing identity is an age file encrypted to the YubiKeys. The yubikey
  module sets `SOPS_AGE_KEY_CMD=sops-age-pq-key`, which decrypts
  `editor-pq.age` with the stubs in `keys.txt` (PIN + touch) and hands the
  identity to sops in memory; without that file it prints nothing.
- `~/.config/sops/age/keys.txt` on editing machines holds only YubiKey
  identity **stubs** (`AGE-PLUGIN-YUBIKEY-…`, not secret). Enable
  `dotfiles.security.yubikey` on any machine you edit from (needs `pcscd`).
- Don't point `dotfiles.sops.ageKeyFile` at that file: activation can't touch
  a YubiKey.

### `.sops.yaml` (in nix-secrets)

Target state (after the PQ switch):

```yaml
keys:
  # you (editing)
  - &editor    age1pq1...   # editor-pq.age, encrypted to YubiKey A + B
  - &backup    age1pq1...   # backup-pq.txt, stored offline
  # hosts (./secrets.sh recipient <host|local>)
  - &mainpc       age1pq1...
  - &macbook      age1pq1...
  - &evo          age1pq1...
  - &vps          age1pq1...
  - &nucserver    age1pq1...
  # - &laptop       TODO_LAPTOP
  # - &laptopserver TODO_LAPTOPSERVER
creation_rules:
  # One file per host: only that host + you can decrypt it.
  - path_regex: hosts/mainpc\.yaml$
    key_groups: [{ age: [*editor, *backup, *mainpc] }]
  - path_regex: hosts/macbook\.yaml$
    key_groups: [{ age: [*editor, *backup, *macbook] }]
  - path_regex: hosts/evo\.yaml$
    key_groups: [{ age: [*editor, *backup, *evo] }]
  - path_regex: hosts/vps\.yaml$
    key_groups: [{ age: [*editor, *backup, *vps] }]
  - path_regex: hosts/nucserver\.yaml$
    key_groups: [{ age: [*editor, *backup, *nucserver] }]
  # Only secrets every host really needs (docker-registry).
  - path_regex: shared\.yaml$
    key_groups:
      - age: [*editor, *backup, *mainpc, *macbook, *evo, *vps, *nucserver]
  # Parked secrets no host declares: you only.
  - path_regex: unused\.yaml$
    key_groups: [{ age: [*editor, *backup] }]
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

### Switch to post-quantum recipients (done 2026-11-16)

Kept as reference for the order of operations.

Order matters: a host must hold its PQ identity before its classical
recipient is dropped, or activation can't decrypt.

1. Build/deploy every sops host with this config (mainpc, macbook, evo, vps,
   nucserver). Activation creates `/var/lib/sops-nix/key.{txt,pub}`; the
   classical recipients keep working meanwhile.
2. Editor key (on mainpc, YubiKeys A + B plugged in / at hand):
   ```bash
   cd ~/.config/sops/age
   age-keygen -pq 2>editor-pq.pub | age -e \
     -r "$(age-plugin-yubikey --list | grep -v '^#' | sed -n 1p)" \
     -r "$(age-plugin-yubikey --list | grep -v '^#' | sed -n 2p)" \
     -o editor-pq.age
   # editor-pq.pub: "Public key: age1pq1…" → &editor
   sops-age-pq-key | head -c 30   # test: PIN + touch, prints "# created: …"
   ```
   (`age-plugin-yubikey --list` only lists plugged-in keys: with one at a
   time, take each key's `age1yubikey1…` from `.sops.yaml` instead.) Copy
   `editor-pq.age` (encrypted, safe to sync) to the other editing machines.
3. Backup key: `age-keygen -pq -o backup-pq.txt` on an offline machine,
   store like the old backup, note its `age1pq1…` → `&backup`.
4. Add the PQ recipients **next to** the old ones in `.sops.yaml`
   (`./secrets.sh recipient <host>` per host), `./secrets.sh rekey`, commit
   the lock, rebuild/deploy all hosts. Check each decrypts:
   `systemctl status` of its secret consumers / `ls /run/secrets`.
5. Remove the classical recipients (`age1yubikey1…`, old `&backup`, host
   `age1…`), `./secrets.sh rekey`; check every file has only `age1pq1…`:
   `grep -h 'recipient:' ~/nix-secrets/{hosts/*,shared,unused}.yaml | grep -vc age1pq1`
   → `0`.
6. Stop decrypting with the SSH host key (`sops.age.sshKeyPaths = [ ]`),
   rebuild/deploy all hosts.
7. Old classically wrapped copies stay in nix-secrets' git history (and in
   every `/nix/store` that fetched it). Rekeying doesn't fix exposure that
   already happened: rotate the actual values you care about.

### YubiKey setup (per key)

```bash
age-plugin-yubikey            # interactive: pick slot, PIN policy, touch=always
age-plugin-yubikey --list     # → recipient age1yubikey1… (encrypt editor-pq.age to it)
age-plugin-yubikey --identity >> ~/.config/sops/age/keys.txt   # stub
```

Repeat with the spare key. Copy `keys.txt` (stubs only) and `editor-pq.age`
to other machines you edit from. A new YubiKey: decrypt `editor-pq.age` with
an old one and re-encrypt it to the new set; `.sops.yaml` doesn't change.

### Reinstalled host / new machine

A fresh install has a new host key → old recipient useless → that host can't
decrypt until re-keyed (it boots; services needing secrets fail).

```bash
./secrets.sh recipient evo       # or `local` on the machine itself
# replace evo's entry in ~/nix-secrets/.sops.yaml
./secrets.sh rekey
./deploy.sh .#evo                # or ./build.sh <host>
```

To skip re-keying, back up `/var/lib/sops-nix/key.txt` and restore it before
the first activation (e.g. `nixos-anywhere --extra-files`). New machine:
generate the key first (`age-keygen -pq -o <extra-files>/var/lib/sops-nix/key.txt`,
mode 0600), add its recipient (`age-keygen -y`), rekey, then install.

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
    vikunja = "tasks.example.com";   # evo API proxy for Hermes (reads + Hermes-labelled task writes)
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
- laptop, laptopserver have no recipient/host file yet (commented out in
  `.sops.yaml`). Before reactivating one: add its recipient + rule, add it to
  the `shared.yaml` rule, `./secrets.sh rekey`.
- Post-quantum switch done 2026-11-16 (steps 1–6). Step 7: values not
  rotated yet; the classical YubiKey / backup / host recipients can still
  decrypt nix-secrets commits before the PQ-only rekey.

## nix-private (private, not secret config)

`Ilosariph/nix-private` is a second private repo, a flake this time, for config
that shouldn't be public but isn't secret: own tools (comfyui-img-finder,
vid-finder, vid-viewer, each with a kitty desktop entry) and later work stuff.
Its `nixosModules.default` is imported only in `modules/hosts/mainpc.nix` and
`modules/hosts/macbook.nix`. Everything in it lands in the world-readable store.

- Fetched via `git+ssh` like nix-secrets (your SSH key; no deploy key on evo,
  so never import it on hosts evaluated by evo's nix-eval).
- Checked out as the `./nix-private` submodule for editing
  (`git submodule update --init` after cloning the dotfiles).
- Try uncommitted edits: `./build.sh --local-private mainpc test`.
- Update tools: `nix flake update` in `nix-private`, commit + push, then
  `nix flake update nix-private` here.
