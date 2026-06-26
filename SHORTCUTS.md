# Keybindings

Window-manager bindings below are for **niri** (the desktop WM used on all
graphical machines). Generated from the `dotfiles.windowManager` options in
`modules/packages/niri/niri.nix`.

> `Mod` = **Super** (Windows key)
>
> Directional keys (`←` `→` `↑` `↓`) depend on keyboard layout:
> | Direction | QWERTY | Colemak |
> |-----------|--------|---------|
> | Left      | `H`    | `N`     |
> | Right     | `L`    | `I`     |
> | Up        | `K`    | `U`     |
> | Down      | `J`    | `,`     |
>
> Arrow keys work as an alternative to the directional keys everywhere below.

---

## Applications

| Shortcut | Action |
|----------|--------|
| `Mod + Q` | Open terminal (kitty) |
| `Mod + E` | Open file manager (yazi) |
| `Mod + Space` | Open app launcher (wofi / noctalia launcher) |
| `Mod + Shift + /` | Show hotkey overlay (all bindings) |
| `Mod + /` | Keybind cheatsheet *(noctalia statusbar only)* |

---

## Session Management

| Shortcut | Action |
|----------|--------|
| `Mod + C` | Close active window |
| `Mod + Alt + L` | Lock screen |
| `Mod + Super + Escape` | Lock screen |
| `Mod + Escape` | Toggle keyboard-shortcuts inhibit |
| `Mod + Shift + E` | Quit niri (exit session) |
| `Ctrl + Alt + Delete` | Quit niri (exit session) |

---

## Focus

| Shortcut | Action |
|----------|--------|
| `Mod + ←` | Focus column left |
| `Mod + →` | Focus column right |
| `Mod + ↑` | Focus window up |
| `Mod + ↓` | Focus window down |
| `Mod + Ctrl + ←/→/↑/↓` | Focus monitor in direction |

---

## Window Management

| Shortcut | Action |
|----------|--------|
| `Mod + V` | Toggle floating |
| `Mod + O` | Toggle overview |
| `Mod + F` | Maximize column |
| `Mod + Shift + F` | Fullscreen window |
| `Mod + R` | Cycle preset column widths |
| `Mod + Shift + R` | Cycle preset window heights |
| `Mod + Ctrl + R` | Reset window height |
| `Mod + T` | Consume window into column |
| `Mod + Shift + T` | Expel window from column |

### Moving Windows

| Shortcut | Action |
|----------|--------|
| `Mod + Shift + ←/→/↑/↓` | Move column / window in direction |
| `Mod + Shift + Ctrl + ←/→/↑/↓` | Move column to monitor in direction |

---

## Workspaces

| Shortcut | Action |
|----------|--------|
| `Mod + 1–9` | Switch to workspace 1–9 |
| `Mod + Shift + 1–9` | Move column to workspace 1–9 |
| `Mod + F1` | Switch to tools workspace |
| `Mod + Shift + F1` | Move column to tools workspace |
| `Mod + Scroll Down` | Next workspace |
| `Mod + Scroll Up` | Previous workspace |

---

## Screenshots

| Shortcut | Action |
|----------|--------|
| `Print` | Screenshot selection → edit in Swappy |
| `Shift + Print` | Screenshot full screen → edit in Swappy |
| `Ctrl + Print` | Screenshot current output → edit in Swappy |

> niri also stores screenshots under `~/Pictures/Screenshots/`.

---

## Audio

| Shortcut | Action |
|----------|--------|
| `Mod + Shift + O` | Switch audio output device (wofi menu) *(pipewire-virtual routing only)* |

---

## Media & Laptop Keys

> These work even while the screen is locked.

| Key | Action |
|-----|--------|
| `XF86AudioRaiseVolume` | Volume +5% |
| `XF86AudioLowerVolume` | Volume –5% |
| `XF86AudioMute` | Toggle mute (output) |
| `XF86AudioMicMute` | Toggle mute (microphone) |
| `XF86MonBrightnessUp` | Brightness +5% |
| `XF86MonBrightnessDown` | Brightness –5% |
| `XF86AudioNext` | Next track |
| `XF86AudioPrev` | Previous track |
| `XF86AudioPlay` / `XF86AudioPause` | Play / Pause |

---

## tmux

> Prefix = `Ctrl + A`
>
> Directional keys match the window manager layout (QWERTY: H/J/K/L, Colemak: N/,/U/I)

### Sessions & Windows

| Shortcut | Action |
|----------|--------|
| `Prefix + c` | New window (keeps current path) |
| `Prefix + \|` | Split pane horizontally |
| `Prefix + -` | Split pane vertically |
| `Prefix + r` | Reload tmux config |
| `Alt + 1–9` | Switch to window 1–9 |

### Pane Navigation

| Shortcut | Action |
|----------|--------|
| `Prefix + ←` | Focus pane left |
| `Prefix + →` | Focus pane right |
| `Prefix + ↑` | Focus pane up |
| `Prefix + ↓` | Focus pane down |

### Pane Resizing

| Shortcut | Action |
|----------|--------|
| `Prefix + Shift + ←` | Resize pane left |
| `Prefix + Shift + →` | Resize pane right |
| `Prefix + Shift + ↑` | Resize pane up |
| `Prefix + Shift + ↓` | Resize pane down |

---

## fzf (Fish Shell)

| Shortcut | Action |
|----------|--------|
| `Ctrl + R` | Fuzzy search command history |
| `Ctrl + T` | Fuzzy search files in current directory |
| `Alt + C` | Fuzzy cd into subdirectory |
