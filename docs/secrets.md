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

Fetched content is stored in `/nix/store` like any input. Still encrypted,
decrypted only at activation with the age key.

## Repo layout (nix-secrets)

```
.sops.yaml      # age recipients + creation rules
secrets.yaml    # all secrets
```

## Day-to-day

```bash
./secrets.sh edit            # pull ~/nix-secrets, sops secrets.yaml,
                             # commit + push, nix flake update nix-secrets
./secrets.sh edit other.yaml # another file in the repo
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
   even after step 4):
   ```bash
   git clone git@github.com:Ilosariph/nix-secrets.git ~/nix-secrets
   cd ~/nixos-config
   git show 1a035e3:secrets/secrets.yaml > ~/nix-secrets/secrets.yaml
   git show 1a035e3:secrets/.sops.yaml   > ~/nix-secrets/.sops.yaml
   cd ~/nix-secrets && git add -A && git commit -m "initial secrets" && git push -u origin main
   ```
3. Lock the input and verify decryption still works:
   ```bash
   cd ~/nixos-config
   nix flake lock            # adds nix-secrets to flake.lock
   sops -d ~/nix-secrets/secrets.yaml >/dev/null && echo ok
   ./build.sh mainpc test
   ```
4. Remove the old copy and commit:
   ```bash
   git rm -r secrets && git commit -am "secrets: move to private nix-secrets repo"
   ```

Note: the encrypted `secrets/` stays in this repo's git history. Fine as long
as the age key is safe; if the repo goes public and that's a concern, rotate
the secrets (or rewrite history).
