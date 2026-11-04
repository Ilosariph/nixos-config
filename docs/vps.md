# VPS

Public server running Pangolin (reverse proxy + tunnels) and the Docker stacks
in `/docker`. Host `vps`, config in `modules/machines/vps/`. Its IP and domains
live in `private.nix` (`dotfiles.private.vps`), not in this repo.

| File | What |
|---|---|
| `options.nix` | dotfiles options: sops host, deploy target, network, ssh keys |
| `configuration.nix` | IPv6, firewall, sshd hardening, docker, user password |
| `disko.nix` | disk layout (BIOS boot + 1G ESP + ext4 root, boots BIOS or UEFI), used by nixos-anywhere |
| `hardware-configuration.nix` | virtio kernel modules |
| `pangolin.nix` | Pangolin, Gerbil, Traefik as nix-declared containers + generated config |
| `crowdsec.nix` | CrowdSec, firewall bouncer, Traefik bouncer key, AppSec, Pangolin login scenario |
| `backup.nix` | nightly restic backup to the storagebox (`restic-backup.timer`) |
| `migration.nix`, `migration/` | one-off Ubuntu → NixOS migration helpers (off: `dotfiles.vps.migration.enable`) |
| `modules/hosts/vps-test.nix` | throwaway rehearsal host, only defined while `private.nix` has `vps.test` |

## Day to day

- Deploy: `deploy .#vps` (from mainpc; SSH as `simon`, root login is off).
- Docker stacks: still `docker compose` in `/docker/compose/<stack>`. `simon` is in the `docker` group.
- Pangolin/Gerbil/Traefik: managed by nix, not compose. Update = bump the tag in
  `images` (or `badgerVersion`) at the top of `pangolin.nix`, deploy. Logs:
  `journalctl -u docker-pangolin` (or `-gerbil`, `-traefik`), restart: `sudo systemctl restart docker-pangolin`.
  Don't update it through anything that edits the old compose file in
  `/docker/important/Pangolin`: that would try to start a second copy.
- Backups: `sudo systemctl start restic-backup` runs one now; `sudo restic-vps snapshots|restore|...`
  has the repo and password preset.
- CrowdSec: `sudo cscli metrics` (are logs parsed), `sudo cscli decisions list` (current bans),
  `sudo cscli decisions delete --ip <ip>` (unban), `sudo cscli bouncers list`.
  `vps.trustedIPs` (private.nix) is never banned or captcha'd. Locked out from
  elsewhere (SSH brute-force ban blocks everything, not just SSH): VNC
  console, log in as `simon`, `sudo cscli decisions delete --ip <ip>`.
  Remediation: crawling/probing → 4h captcha; Pangolin logins (incl. resource
  password/pin/OTP) → captcha after 5 failures, ban after 10: 2h, doubling for
  each earlier one within 48h, up to 32h; everything else → ban 4h, +4h per repeat.
  Bans block all ports (firewall bouncer), captchas only web requests.
- sudo asks for simon's password: run it in a real terminal (`ssh -t`), not via
  Claude Code's `!`. Long jobs (restore) inside `tmux new -s <name>`.
- Reboots: shutdown takes a few seconds (dockerd stops every container, no
  live-restore). After boot, 80/443 stay closed ~30–40s until Pangolin is
  healthy and Gerbil/Traefik start.
- Broken generation (e.g. no network after a deploy): VNC console,
  reboot, press ↓ in GRUB (5s), "NixOS - All configurations", pick the previous
  one. One-time; the default stays the newest until you deploy or
  `sudo /run/current-system/bin/switch-to-configuration boot` from the old one.

## Before switching

Everything here is done while Ubuntu keeps running. Take your time.

1. **`private.nix`** (`./secrets.sh edit private.nix`), add:
   ```nix
   vps = {
     ipv4 = "<vps ipv4>";
     ipv6 = "<vps ipv6>";               # without /64
     gateway = "<ipv4 gateway>";
     authorizedKeys = [ "<the ssh-ed25519 key in root's authorized_keys on Ubuntu>" ];
     storagebox = { host = "<host>"; user = "<user>"; port = <port>; };
     backupHealthcheckUrl = "";        # healthchecks.io ping URL, e.g. https://hc-ping.com/<uuid> (empty = disabled)
     pangolin = {
       dashboardDomain = "<pangolin.example.com>";
       baseDomain = "<example.com>";
       letsEncryptEmail = "<email from traefik_config.yml>";
       wildcardDomains = [ <every domain from the next-router tls.domains list in dynamic_config.yml> ];
     };
     # optional: never banned by CrowdSec, never captcha'd by the Traefik plugin
     trustedIPs = [ "<home ip>/32" ];
   };
   ```
   Current values: `ip -br a`, `ip r`, `cat /root/.ssh/authorized_keys`, `cat /root/.ssh/config`,
   `/docker/important/Pangolin/config/traefik/*.yml` on the VPS.

2. **sops recipient.** The install keeps Ubuntu's SSH host key, so its age key can be added now:
   ```bash
   ssh root@$VPS cat /etc/ssh/ssh_host_ed25519_key.pub | nix run nixpkgs#ssh-to-age
   ```
   In `nix-secrets/.sops.yaml` add `- &vps age1...` under hosts and a rule
   `- path_regex: hosts/vps\.yaml$` / `key_groups: [{ age: [*yubikey_a, *yubikey_b, *backup, *vps] }]`.

3. **Secrets** (`./secrets.sh edit vps`):

   | Key | Value |
   |---|---|
   | `restic-password` | `/root/.restic-pass` |
   | `storagebox-ssh-key` | `/root/.ssh/id_storagebox` (multi-line, use a `\|` block) |
   | `backup-discord-webhook` | `DISCORD_WEBHOOK` in `/usr/local/bin/backup.sh` |
   | `docker-config` | `/root/.docker/config.json` (registry login) |
   | `pangolin-server-secret` | `server.secret` in `/docker/important/Pangolin/config/config.yml` |
   | `cloudflare-dns-api-token` | `/docker/important/Pangolin/.env` |
   | `crowdsec-traefik-bouncer-key` | new random string: `openssl rand -hex 32` |
   | `turnstile-site-key` / `turnstile-secret-key` | Cloudflare Turnstile widget with all `wildcardDomains` as hostnames |
   | `simon-password-hash` | `mkpasswd -m yescrypt` (sudo + VNC console login) |

4. **Build and test locally** (from the `vps` branch, after `./secrets.sh` bumped `flake.lock`):
   ```bash
   nix build .#nixosConfigurations.vps.config.system.build.toplevel
   # VM: partitions a disk with disko, installs, boots (checks BIOS/GRUB)
   nix build -L .#nixosConfigurations.vps.config.system.build.installTest
   ```

5. **Check the backup works** on Ubuntu (the migration depends on it):
   `ssh root@$VPS 'systemctl start backup.service && journalctl -u backup -n 20'`.

6. **Provider panel:** know how to open the VNC console (fallback if the network doesn't
   come up) and whether you can take a snapshot (rollback, see below).

7. Plan **~60–75 min downtime**: every site and Pangolin tunnel is down from step 1
   to step 4 below. DNS doesn't change (same server, same IP). Measured:
   install ~5–10 min, restore 30–50 min (mostly the restic restore, image pulls
   are quick).

8. **Rehearse on a test VPS** (next section). Covers what the local VM test can't:
   the VPS network after kexec and reboot, BIOS vs UEFI, sops on first boot,
   real restore and pull times.

## Test run (rehearsal on a second VPS)

Same install and restore against a throwaway VPS, while prod keeps
running. The `vps-test` host is the `vps` config with the test server's
address, hostname `vps-test` and **no restic backup timer** (same repo and paths
as prod: its nightly `forget` would prune prod's snapshots).

1. **Order** a VPS like prod, with disk for `/docker` + images + nix (compare
   `df -h` and `docker system df` on prod), Ubuntu 24.04, monthly. Put
   in your SSH key. Cancel right away so it ends after the month.

2. **Check boot mode and network** on the fresh Ubuntu, for comparison:
   ```bash
   ssh root@$TEST 'ls /sys/firmware/efi >/dev/null 2>&1 && echo UEFI || echo BIOS; ip -br a; ip r; ip -6 r; cat /etc/netplan/*.yaml'
   ```
   `disko.nix` boots either way. If netplan has more than static addresses + routes
   (e.g. `dhcp4: true`), adapt the network config before installing.

3. **`private.nix`**: add `test = { ipv4 = "..."; ipv6 = "..."; gateway = "..."; prefixLength = ...; };`
   inside the `vps` block (`ipv6` without `/64`; `prefixLength` from netplan,
   default 24). That defines `nixosConfigurations.vps-test`
   and the `deploy .#vps-test` node.

   **Own host key** (not prod's), added as a second recipient of `hosts/vps.yaml`:
   ```bash
   keys=~/vps-test-extra
   install -d -m 755 $keys/etc/ssh
   ssh-keygen -t ed25519 -N "" -C root@vps-test -f $keys/etc/ssh/ssh_host_ed25519_key
   nix run nixpkgs#ssh-to-age < $keys/etc/ssh/ssh_host_ed25519_key.pub
   ```
   In `nix-secrets/.sops.yaml` add `- &vps_test age1...` and `*vps_test` to the
   `hosts/vps\.yaml` rule, then `./secrets.sh rekey`.

4. **Snapshot prod without stopping it:**
   ```bash
   ssh root@$VPS 'bash -s -- --test' < modules/machines/vps/migration/pre-switch.sh
   ```
   Runs the normal backup, records stacks and images, then takes a
   `nixos-migration-test` snapshot of `/docker` while the five DB containers
   are **paused** (crash-consistent data dirs; their apps stall for the
   snapshot's duration, a few minutes at most since restic only reads changes).

5. **Install** with that key (wipes the test server):
   ```bash
   TEST=$(nix eval --raw .#nixosConfigurations.vps-test.config.dotfiles.private.vps.ipv4)
   time nix run github:nix-community/nixos-anywhere -- \
     --flake .#vps-test --target-host root@$TEST --extra-files ~/vps-test-extra --chown /etc/ssh 0:0
   ssh-keygen -R $TEST   # new host key; log in as simon from now on
   ```
   Reboot once more afterwards (`ssh simon@$TEST sudo reboot`) to see the
   network come up from the installed config, not just right after install.

6. **Restore:** `ssh simon@$TEST` then
   `time sudo vps-migrate-restore --test --skip <stack> ...`. `--test` restores
   the test snapshot. Skip every stack that would act on prod or notify people:
   anything holding prod API keys, `uptime` (duplicate alerts), `vikunja`
   (reminder mails), `monkeytype` (shares a Firebase project with prod). The
   script refuses to run on `vps-test` without `--test`.

7. **Check** the same list as in "Switching" step 5. Sites: DNS still points
   at prod, so add the domains to `/etc/hosts` on mainpc pointing at `$TEST`
   (or `curl --resolve <host>:443:$TEST https://<host>`). Newt sites keep
   talking to prod. Also try `deploy .#vps-test` once.

8. **Clean up:** `sudo restic-vps forget --prune <id>` (id from `sudo restic-vps snapshots --tag nixos-migration-test`; `forget` needs ids or a policy, a tag alone removes nothing)
   (on the test server or later on prod), remove `vps.test` from `private.nix`,
   `ssh-keygen -R $TEST`, remove `&vps_test` from `.sops.yaml` and `./secrets.sh rekey`,
   `rm -r ~/vps-test-extra`, `/etc/hosts` back if you pointed domains at the
   test server (`sudo ~/vps-test-hosts.sh off`), cancel the test VPS
   (or let it run out). The test server has prod's secrets until it's gone.

## Switching

All commands here and in "Test run" are **bash** (`VAR=$(...)`, `"$tmp"`); fish
rejects them. Run `bash --norc` in the dotfiles repo first (plain `bash` execs fish via `.bashrc`). Before starting:
`/etc/hosts` on mainpc must not point at the test server (`sudo ~/vps-test-hosts.sh off`).
Step 3 copies prod's SSH host key: run it yourself, not via Claude Code.
Set `dotfiles.vps.migration.enable = true;` in `options.nix` first (step 4 needs
`vps-migrate-restore`), turn it off again afterwards.

`VPS=$(nix eval --raw .#nixosConfigurations.vps.config.dotfiles.private.vps.ipv4)`

1. **Stop and snapshot** (on Ubuntu, downtime starts):
   ```bash
   ssh root@$VPS 'bash -s' < modules/machines/vps/migration/pre-switch.sh
   ```
   Runs the normal backup, records running stacks (`/docker/.migration/stacks.txt`)
   and the exact image digest of every container (`images.txt`), stops all containers
   and docker, then takes a restic snapshot tagged `nixos-migration` of `/docker`
   (raw DB data dirs included, they're consistent now) plus `/root`, `/opt`, `/etc`
   for reference. Read its output: stack dirs that don't exist are warned about.

   *Abort here:* `ssh root@$VPS 'systemctl start docker && xargs docker start < /docker/.migration/running-ids.txt'`.

2. **Optional: provider snapshot** now (docker is stopped, so it's consistent).

3. **Install NixOS.** Wipes the disk. Keeps the SSH host key, so sops can decrypt
   on first boot and `known_hosts` stays valid:
   ```bash
   tmp=$(mktemp -d)
   install -d -m 755 "$tmp/etc/ssh"
   ssh root@$VPS cat /etc/ssh/ssh_host_ed25519_key > "$tmp/etc/ssh/ssh_host_ed25519_key"
   ssh root@$VPS cat /etc/ssh/ssh_host_ed25519_key.pub > "$tmp/etc/ssh/ssh_host_ed25519_key.pub"
   chmod 600 "$tmp/etc/ssh/ssh_host_ed25519_key"

   nix run github:nix-community/nixos-anywhere -- \
     --flake .#vps \
     --target-host root@$VPS \
     --extra-files "$tmp" \
     --chown /etc/ssh 0:0

   rm -rf "$tmp"
   ```
   It kexecs into a NixOS installer (reusing Ubuntu's IP config), partitions with
   `disko.nix`, installs and reboots. If SSH doesn't come back after a few minutes,
   check the VNC console (log in as `simon` with the password from `simon-password-hash`).

4. **Restore** (on NixOS, ~50 min; in tmux so a dropped SSH session doesn't matter):
   ```bash
   ssh -t simon@$VPS tmux new -s restore
   time sudo vps-migrate-restore
   ```
   Detach `Ctrl-b d`, reattach `ssh -t simon@$VPS tmux attach -t restore`.
   Restores `/docker` from the `nixos-migration` snapshot, starts Pangolin (it
   refuses to start on an empty `/docker`), brings the registry stack up first,
   pulls every image by its recorded digest and tags it (no surprise upgrades of
   `mariadb`, `redis`, `:latest`), then `docker compose up -d` in every recorded
   stack. Ends with a list of anything that failed.

5. **Verify:**
   - all sites load, Pangolin dashboard works, sites/newt tunnels are connected
   - `docker ps` matches what ran before (`/docker/.migration/stacks.txt`)
   - `sudo cscli metrics`: `journalctl` sources show read/parsed lines for sshd, traefik, pangolin;
     `sudo cscli bouncers list`: `crowdsec-firewall-bouncer` and `traefik` with a recent last pull
   - **first backup right away**, don't wait for the timer:
     `sudo systemctl start restic-backup && journalctl -u restic-backup -f`
     (first run on the new hostname has no parent snapshot: reads all of `/docker`
     again, uploads little). Discord only hears about failures.
   - from mainpc: `deploy .#vps` works (deploy-rs, no-op change is fine)
   - one `sudo reboot`: all containers come back on their own (`docker ps -a --filter status=exited`)

## After switching

- Clean up the test server: "Test run" step 8.
- Old restic snapshots from Ubuntu stay usable (same repo, same password).
- The `nixos-migration` snapshot has its own path set, so the nightly `forget`
  keeps it forever. Once happy: `sudo restic-vps forget --prune <id>` (id from `sudo restic-vps snapshots --tag nixos-migration`).
- SQLite dumps in nightly snapshots are now named after the path below `/docker`
  (`data_...`, `important_...`), Pangolin's `db.sqlite` is included.
- `migration.nix` is off (`dotfiles.vps.migration.enable`, on only for `vps-test`): no
  `vps-migrate-restore` on prod. Turn it on in `options.nix` for a rerun.
- Not migrated (were inactive or leftovers on Ubuntu, still in the migration
  snapshot under `/opt`, `/root`, `/home/docker`): preview-deployments ui/webhook
  servers, dockge backup.
- `/docker/important/Pangolin/{docker-compose.yml,.env,config/traefik,config/config.yml}`
  and `update.sh`/`recover.sh` are unused now (nix generates all of it).

## Rollback

- Before step 3: the abort command in step 1.
- After step 3: restore the provider snapshot from step 2, then
  `systemctl start docker && xargs docker start < /docker/.migration/running-ids.txt`.
  Without a snapshot: reinstall Ubuntu from the provider panel and restore `/docker`
  from the `nixos-migration` snapshot with restic (needs docker + compose reinstalled).
