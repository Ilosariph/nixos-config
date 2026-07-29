# Ansible: niri + noctalia on Fedora

An Ansible port of this repo's NixOS/home-manager desktop config, for machines
that can't run the flake — specifically **Fedora Asahi Remix (aarch64)** on the
MacBook. It installs the window manager, the shell, and the everyday apps, and
writes the same dotfiles the Nix modules generate.

Everything here is a translation of `modules/packages/<aspect>/<aspect>.nix`;
each role names the module it came from.

## Running it

The playbook configures the machine it runs on. Copy the repo over, then:

```bash
sudo dnf install ansible-core
cd nixos-config/ansible
ansible-galaxy collection install -r requirements.yml
ansible-playbook site.yml -K
```

`-K` prompts once for the sudo password. Re-running is safe — every task is
idempotent apart from the "best effort" package probes, which just retry.

Useful subsets:

```bash
ansible-playbook site.yml -K --tags niri,noctalia   # just the desktop shell
ansible-playbook site.yml -K --tags 1password
ansible-playbook site.yml -K --skip-tags noctalia   # everything but the bar
ansible-playbook site.yml -K --check --diff         # dry run
```

After the first run, log out and pick **niri** in the session list.

## Keyboard layout

The one intentional difference from mainpc: this machine uses **qwerty**
directional keys, mainpc uses colemak.

| Direction | qwerty | colemak |
|-----------|--------|---------|
| Left      | `H`    | `N`     |
| Right     | `L`    | `I`     |
| Up        | `K`    | `U`     |
| Down      | `J`    | `,`     |

Set by `wm_keyboard_layout` in `host_vars/localhost.yml`. Everything else
(`SHORTCUTS.md`) applies unchanged.

This is separate from the *typing* layout: `dotfiles_xkb_layout` still defaults
to `ch-nodead-cflex`, the custom Swiss German layout from `base.nix`. The niri
role installs its xkb symbols file to `/usr/share/X11/xkb/symbols/`.

## What gets installed

| Role | Source module | Notes |
|------|---------------|-------|
| `base` | `base/base.nix` | CLI tools, locale, timezone, RPM Fusion, flathub |
| `fonts` | `desktop.nix` | JetBrains Mono + Nerd Font variants |
| `desktop` | `desktop.nix` | Firefox, Chromium, Dolphin, VLC, GIMP, LibreOffice, GTK theme, mimeapps, udiskie |
| `shell` | `fish.nix`, `bash.nix` | fish as login shell, starship, fzf |
| `kitty` | `kitty.nix` | Tokyo Night Night colours inlined |
| `niri` | `niri.nix` | compositor, `config.kdl`, session env, xwayland-satellite |
| `noctalia` | `noctalia.nix` | bar/shell from COPR, settings, random wallpaper |
| `wofi` | `wofi.nix` | launcher config + stylesheet, verbatim |
| `yazi` | `yazi.nix` | config, keymap, `yy` wrapper |
| `git` | `git.nix` | gitconfig with 1Password SSH signing, ssh config |
| `onepassword` | `1password.nix` | app + CLI |
| `proton` | `vpn.nix` | Proton Mail, Proton VPN, WireGuard profiles |
| `obsidian` | `desktop.nix` | AppImage + launcher |
| `zed` | `zed.nix` | official installer, settings, keymap |
| `mpv` | `mpv.nix` | config + bindings |
| `swappy` | `swappy.nix` | screenshot editor config |

## aarch64 caveats

Apple Silicon means several upstreams have no arm64 package. Where that's true
the role picks the supported route rather than failing:

- **1Password** — no arm64 rpm. Installed from the official arm64 tarball into
  `/opt/1Password` via its `after-install.sh`; the CLI comes from the release
  zip (pin with `onepassword_cli_version`). Turn on *Settings → Developer → Use
  the SSH agent* afterwards, or git signing and `~/.ssh/config` won't work.
- **Obsidian** — no arm64 `.rpm`/`.deb`, only an AppImage. Downloaded to
  `/opt/obsidian` with a `/usr/local/bin/obsidian` symlink, a desktop entry and
  the icon unpacked from the image. Version resolves from the GitHub API unless
  you pin `obsidian_version`.
- **Proton Mail** — Proton publishes **no** arm64 build at all. Default here is
  `protonmail_install_method: webapp`, a launcher that opens `mail.proton.me`
  in its own Firefox window. Third-party aarch64 rebuilds exist; the playbook
  won't pick one for you, but set `protonmail_community_rpm_url` to a release
  you trust and switch the method to `community_rpm` if you want one.
- **Proton VPN** — the GUI app is x86_64-only, so on aarch64 the role imports
  `/etc/wireguard/{home,proton}.conf` into NetworkManager with autoconnect off,
  exactly like `vpn.nix` does. Put those files in place first (they are never
  generated here); missing ones are reported and skipped.
- **Noctalia** — not in Fedora's repos; comes from `copr:zhangyi6324/noctalia-shell`.
  That COPR does not build for every release/arch combination. If the install
  fails the role stops with the alternatives spelled out, and the rest of the
  playbook still runs with `--skip-tags noctalia`.

Packages that simply may not exist on a given Fedora release (Nerd Fonts,
`xwayland-satellite`, `qview`, yazi) are probed and reported rather than fatal;
yazi and the fonts fall back to upstream release artifacts.

## Things this playbook deliberately leaves alone

- **The display manager.** Fedora Asahi ships GDM and niri registers its own
  Wayland session, so there's nothing to swap. `greetd.nix` has no counterpart
  here.
- **xdg-desktop-portal config.** The `niri` package ships
  `/usr/share/xdg-desktop-portal/niri-portals.conf`; overriding it would break
  screencasting, so the role doesn't write one.
- **Audio routing.** `audio-routing.nix` (virtual sinks, mic effects chain) is
  mainpc-specific and isn't ported. `wm_audio_switcher_binds` stays false so
  niri doesn't bind keys to scripts that don't exist here.
- **Cursor theme.** `material-cursors` isn't packaged for Fedora and needs a
  source build, so `cursor_theme` defaults to whatever is installed. Point it
  at a theme in `~/.icons` if you build one.
- **Secrets.** No sops/age wiring; `age` is installed, nothing is decrypted.

## Layout

```
ansible/
├── ansible.cfg           # local connection, sudo prompt
├── inventory.ini
├── requirements.yml      # community.general
├── site.yml              # role order + tags
├── group_vars/all.yml    # every knob, mirrors options.nix
├── host_vars/localhost.yml   # this machine: qwerty, eDP-1, VPN accounts
└── roles/
```

Machine-specific settings belong in `host_vars/`; shared defaults in
`group_vars/all.yml`. To configure a second machine, add a `host_vars/<name>.yml`
and put it in the `workstations` group.

## Notes

- niri hot-reloads `config.kdl`, so a re-run applies keybinding changes without
  logging out. The role runs `niri validate` before installing the file, so a
  broken template can't leave you with an unusable session.
- Noctalia merges every `*.toml` in `~/.config/noctalia/` alphabetically. This
  playbook owns `10-dotfiles.toml`; changes made in Noctalia's own settings UI
  land in `~/.local/state/noctalia/settings.toml` and are left untouched.
- The GTK theme is unpacked from upstream into `~/.themes`. If the variant
  named by `gtk_theme` isn't in the tarball, the run prints the names that are.
