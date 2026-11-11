# nucserver

Home server: Immich and other docker compose stacks, media and backups on the NAS. Config in `modules/machines/nucserver/`, IP from
`private.nix` (`hosts.nucserver`).

| File | What |
|---|---|
| `options.nix` | dotfiles options: network, shares, newt, backup jobs (stacks, Immich), deploy |
| `configuration.nix` | firewall, sshd hardening, docker, user password, secrets |
| `disko.nix` | GPT: BIOS boot + ESP + LUKS/ext4 root, boots BIOS or UEFI |
| `migration.nix`, `migration/` | one-off Ubuntu → NixOS helpers (`dotfiles.nucserver.migration.enable`) |

## Day to day

- Deploy: `deploy .#nucserver`. Stacks: `docker compose` in `/home/simon/docker/<stack>`
  and `/home/docker-data/immich`.
- Backups: `sudo systemctl start backup-immich` / `backup-docker-configs`.
- Reboots are unattended: the TPM unlocks LUKS. If it stops doing that (TPM cleared,
  board replaced) a keyboard + monitor on the box is needed for the passphrase;
  afterwards re-enroll: `sudo systemd-cryptenroll --tpm2-device=auto --tpm2-pcrs= /dev/disk/by-partlabel/disk-main-root`.
- Every `reboot` is a power cycle (~3.5 min: 60 s off, ~2 min POST): the firmware
  sometimes hangs in POST after a warm reset, so the `cold-reboot` shutdown hook in
  `configuration.nix` sets an RTC alarm and powers off instead. Needs BIOS "Wake System
  from S5" **off** (its schedule replaces the alarm). Stays off → `wol nucserver`.
- Debugging what happens after `Journal stopped`:
  `echo Y | sudo tee /sys/module/printk/parameters/always_kmsg_dump`, reboot, read
  `/var/lib/systemd/pstore/*/001/dmesg.txt` (EFI pstore, one boot only).

## Before switching

Ubuntu keeps running for all of this. All commands in this file are **bash**:
run `bash --norc` first.

1. **`private.nix`** (`./secrets.sh edit private.nix`), next to `hosts.evo`:
   `hosts.nucserver = "<current IP>";`. Static from now on: keep the router's
   reservation for this NIC so nothing else gets the address.
2. **sops recipient**: `ssh simon@$NUC cat /etc/ssh/ssh_host_ed25519_key.pub | nix run nixpkgs#ssh-to-age`,
   in `nix-secrets/.sops.yaml` uncomment `&nucserver` and its `hosts/nucserver\.yaml` rule
   (the install keeps the host key). No `shared.yaml` entry needed.
3. **Secrets** (`./secrets.sh edit nucserver`):

   | Key | Value |
   |---|---|
   | `simon-password-hash` | `mkpasswd -m yescrypt` |
   | `smb-<share>`, one per entry in `dotfiles.shares` | `/root/.smbcredentials-<share>` (multi-line, use a `\|` block) |
   | `nucserver-newt-id`, `nucserver-newt-secret` | Pangolin: new site of type Newt |

   Stack secrets (`.env`, compose files) stay in the stack dirs and come back with the restore.
4. **Pangolin**: create the resource for each route of the old tunnel on the new site, target
   `localhost:<published port>`. Apps with their own login and mobile clients need the
   resource's auth off, or the clients can't get through.
5. **Build**: `nix build .#nixosConfigurations.nucserver.config.system.build.toplevel`.
   Skip `system.build.installTest`: the VM has no TPM, so it installs and boots to the
   LUKS prompt and then waits there forever (seen: disko, GRUB for BIOS + EFI, prompt OK).
6. **Dry run of the NAS path** (no downtime, measures throughput):
   `scp modules/machines/nucserver/migration/pre-switch.sh simon@$NUC:/tmp/`,
   `ssh -t simon@$NUC sudo bash /tmp/pre-switch.sh --test`. Delete
   `/mnt/docker-backup/nucserver-migration-test` afterwards.
7. **Root SSH on Ubuntu for kexec**, temporarily:
   `ssh -t simon@$NUC 'sudo install -d -m 700 /root/.ssh && sudo cp ~/.ssh/authorized_keys /root/.ssh/'`.
8. Keep a monitor + keyboard within reach (fallback only) and the LUKS passphrase at hand.

## Switching

Plan ~2.5–3.5 h (archive to the NAS, read back, unpack;
step 6 above refines it). Avoid 03:00, the backup jobs run then.

`NUC=$(nix eval --raw .#nixosConfigurations.nucserver.config.dotfiles.private.hosts.nucserver)`

1. **Stop and archive** (downtime starts): `ssh -t simon@$NUC sudo bash /tmp/pre-switch.sh --drop <path> ...`
   with one `--drop` per directory that isn't coming along (scp it again if `/tmp` was
   cleaned). Read its output, all checksums must be OK: the
   next step destroys the only other copy.

   *Abort here:* the command it prints.

2. **Install. Wipes the disk.**
   ```bash
   tmp=$(mktemp -d)
   install -d -m 755 "$tmp/etc/ssh"
   ssh root@$NUC cat /etc/ssh/ssh_host_ed25519_key > "$tmp/etc/ssh/ssh_host_ed25519_key"
   ssh root@$NUC cat /etc/ssh/ssh_host_ed25519_key.pub > "$tmp/etc/ssh/ssh_host_ed25519_key.pub"
   chmod 600 "$tmp/etc/ssh/ssh_host_ed25519_key"
   test -s "$tmp/etc/ssh/ssh_host_ed25519_key" && test -s "$tmp/etc/ssh/ssh_host_ed25519_key.pub"

   # Pasting works here, input is hidden. Keep the passphrase in your password manager.
   key=$(mktemp); read -rs -p 'LUKS passphrase: ' p; printf %s "$p" > "$key"; unset p

   nix run github:nix-community/nixos-anywhere -- \
     --flake .#nucserver \
     --target-host root@$NUC \
     --phases kexec,disko,install \
     --disk-encryption-keys /tmp/secret.key "$key" \
     --extra-files "$tmp" \
     --chown /etc/ssh 0:0
   ```

3. **Seal LUKS to the TPM**, still in the installer, so the first boot needs nobody:
   ```bash
   installer=(-o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null root@$NUC)
   ssh "${installer[@]}" 'cat > /tmp/enroll.key && systemd-cryptenroll --tpm2-device=auto --tpm2-pcrs= --unlock-key-file=/tmp/enroll.key /dev/disk/by-partlabel/disk-main-root' < "$key"
   ssh "${installer[@]}" reboot
   rm -rf "$tmp" "$key"
   ```
   It has to come back with no key press. If the enroll fails or it stops at the
   passphrase prompt: type it on a keyboard attached to the box (no paste there), then
   run the enroll command from "Day to day" over SSH and reboot.

   Sealed without PCRs on purpose, which is also why sealing from the installer works:
   without Secure Boot, PCR policies would mostly add failed unlocks after firmware or
   bootloader updates, not protection. A stolen disk stays encrypted; the whole box
   stolen does not.

4. **Restore** (in tmux): `ssh -t simon@$NUC tmux new -s restore`, then
   `time sudo nucserver-migrate-restore --skip <old tunnel stack>`. Stops before starting
   anything if owners or modes differ from Ubuntu. Ends with a list of what failed. Only
   stacks that ran on Ubuntu start; other restored stacks stay stopped.

5. **Verify**
   - `systemctl --failed` empty, `systemctl status pangolin-newt`, site online in Pangolin
   - `docker ps` against `/mnt/docker-backup/nucserver-migration/stacks.txt`
   - a container binding the NAS sees its files (`docker exec <container> ls <path>`), `systemctl show 'mnt-*.automount' -p TimeoutIdleUSec` is 0
   - Immich: old photo opens, new upload from the phone works, `docker logs immich_server 2>&1 | grep -iE 'EACCES|permission'` is empty
   - host-networked containers reach their LAN devices and are reachable (firewall)
   - first backups by hand: `sudo systemctl start backup-docker-configs backup-immich`
   - `deploy .#nucserver`, then one more `sudo reboot`: everything back on its own

6. **Cut over public access**: point the DNS name of each old tunnel route at Pangolin
   (replace the record, DNS only), delete the old tunnel.

## After switching

- `dotfiles.nucserver.migration.enable` off.
- `/mnt/docker-backup/nucserver-migration` is the rollback copy. Delete once happy.

## Rollback

- Before step 2: the abort command from step 1.
- After step 2: no snapshot exists (a disk image doesn't fit the NAS).
  Reinstall Ubuntu + docker, unpack the archives. Hours.
