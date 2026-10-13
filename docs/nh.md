# nh — Nix helper

[nh](https://github.com/nix-community/nh) wraps `nixos-rebuild`, `home-manager`
and `nix-collect-garbage` with nicer output. Enabled on every host via
`modules/packages/nh/nh.nix`; `build.sh` uses it.

## What it adds over plain nixos-rebuild

- **Build tree** — live progress view via nix-output-monitor.
- **Closure diff** — before activating, lists added/removed/updated packages
  and size change between current and new generation.
- **Confirmation** — `--ask` / `-a` shows the diff and asks before activating.
- **Self-elevation** — builds as your user, only uses sudo for activation.
  Never run `nh` with `sudo`.
- **Smarter GC** — `nh clean` keeps generations by count and/or age, also
  cleans gcroots (direnv, `result` links).
- **Package search** — `nh search` queries search.nixos.org, fast.

## Commands

| Command | What |
|---|---|
| `nh os switch . -H mainpc` | build + activate + make boot default |
| `nh os boot . -H mainpc` | build, activate on next boot |
| `nh os test . -H mainpc` | build + activate, no boot entry |
| `nh os build . -H mainpc` | build only, show diff |
| `nh os build-vm . -H mainpc` | build a QEMU VM |
| `nh os switch . -H mainpc -a` | show diff, ask before activating |
| `nh os switch . -H mainpc -n` | dry run |
| `nh os switch . -H mainpc -u` | `nix flake update` first, then switch |
| `nh os switch . -H mainpc --update-input nixpkgs` | update one input, then switch |
| `nh os rollback` | activate previous generation |
| `nh os info` | list system generations |
| `nh os repl . -H mainpc` | `nix repl` with the host config loaded |
| `nh home switch . -c <name>` | standalone home-manager (needs `homeConfigurations`) |
| `nh clean all --keep 5 --keep-since 7d` | GC: keep ≥5 gens and anything newer than 7d |
| `nh clean user` | clean only the current user's profiles |
| `nh search <query>` | search nixpkgs |

Extra args for nix go after `--`, e.g. `nh os switch . -H mainpc -- --impure --show-trace`.

## Defaults via env

`NH_FLAKE` (or `programs.nh.flake`) sets the default flake so `.` can be
omitted, e.g. `NH_FLAKE=~/nixos-config nh os switch`. Not set here —
`build.sh` always runs from repo root. `NH_OS_FLAKE` / `NH_HOME_FLAKE`
override per subcommand.

## Automatic cleanup

`programs.nh.clean` runs `nh clean all --keep-since 7d --keep 5` weekly.
Conflicts with `nix.gc.automatic` — don't enable both.

## build.sh mapping

```bash
./build.sh [flake-name] [nix|boot|test|home|vm] [optional-label]
```

| Mode | Runs |
|---|---|
| `nix` (default) | `nh os switch . -H <flake>` |
| `boot` | `nh os boot . -H <flake>` |
| `test` | `nh os test . -H <flake>` |
| `home` | `nh home switch . -c <flake>` |
| `vm` | `nh os build-vm . -H <flake>` (old `result`/`*.qcow2` removed first) |

A label sets `NIXOS_LABEL` and adds `-- --impure` (needed for the label to
reach flake eval).

## Bootstrap (nh not installed yet)

`build.sh` falls back to `nix run --inputs-from . nixpkgs#nh` when `nh` isn't
on PATH — runs nh from this flake's locked nixpkgs. First successful switch
installs nh system-wide. Avoid `nix-shell -p nh`: uses the system channel,
which may be missing or ship an older nh with a different CLI.
Manual fallback: `sudo nixos-rebuild switch --flake .#<host>`.
