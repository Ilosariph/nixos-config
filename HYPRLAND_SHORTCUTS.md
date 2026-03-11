# Hyprland Keybindings

> `$mod` = **Super** (Windows key)
>
> Directional keys (`←` `→` `↑` `↓`) depend on keyboard layout:
> | Direction | QWERTY | Colemak |
> |-----------|--------|---------|
> | Left      | `H`    | `N`     |
> | Right     | `L`    | `I`     |
> | Up        | `K`    | `U`     |
> | Down      | `J`    | `,`     |

---

## Applications

| Shortcut | Action |
|----------|--------|
| `$mod + Q` | Open terminal (kitty) |
| `$mod + E` | Open file manager (yazi) |
| `$mod + Space` | Open app launcher (wofi) |

---

## Session Management

| Shortcut | Action |
|----------|--------|
| `$mod + C` | Close active window |
| `$mod + W` | Close active window |
| `$mod + Backspace` | Close active window |
| `$mod + Escape` | Lock screen |
| `$mod + Alt + L` | Lock screen |
| `$mod + Shift + Escape` | Exit Hyprland |
| `$mod + Ctrl + Escape` | Reboot |
| `$mod + Shift + Ctrl + Escape` | Power off |

---

## Focus

| Shortcut | Action |
|----------|--------|
| `$mod + ←` | Move focus left |
| `$mod + →` | Move focus right |
| `$mod + ↑` | Move focus up |
| `$mod + ↓` | Move focus down |

---

## Window Management

| Shortcut | Action |
|----------|--------|
| `$mod + V` | Toggle floating |
| `$mod + T` | Toggle split direction |
| `$mod + P` | Toggle pseudo-tiling |
| `$mod + Shift + +` | Fullscreen |
| `$mod + Shift + ←` | Swap window left |
| `$mod + Shift + →` | Swap window right |
| `$mod + Shift + ↑` | Swap window up |
| `$mod + Shift + ↓` | Swap window down |

### Move Floating Window (fine-grained)

| Shortcut | Action |
|----------|--------|
| `$mod + Alt + ←` | Move window left 50px |
| `$mod + Alt + →` | Move window right 50px |
| `$mod + Alt + ↑` | Move window up 50px |
| `$mod + Alt + ↓` | Move window down 50px |

---

## Resize

| Shortcut | Action |
|----------|--------|
| `$mod + Ctrl + ←` | Resize window left (–50px, repeating) |
| `$mod + Ctrl + →` | Resize window right (+50px, repeating) |
| `$mod + Ctrl + ↑` | Resize window up (–50px, repeating) |
| `$mod + Ctrl + ↓` | Resize window down (+50px, repeating) |

---

## Workspaces

| Shortcut | Action |
|----------|--------|
| `$mod + 1–9` | Switch to workspace 1–9 |
| `$mod + Shift + 1–9` | Move active window to workspace 1–9 |
| `$mod + Scroll Down` | Next workspace |
| `$mod + Scroll Up` | Previous workspace |

### Special Workspace

| Shortcut | Action |
|----------|--------|
| `$mod + S` | Toggle special workspace |
| `$mod + Shift + S` | Move window to special workspace |
| `$mod + F1` | Toggle Pulsemeeter |

---

## Screenshots

| Shortcut | Action |
|----------|--------|
| `Print` | Screenshot selection → edit in Swappy |
| `Shift + Print` | Screenshot full screen → edit in Swappy |
| `Ctrl + Print` | Screenshot active window → edit in Swappy |
| `$mod + Print` | Pick color (hyprpicker, copies to clipboard) |

---

## Clipboard

| Shortcut | Action |
|----------|--------|
| `$mod + Shift + V` | Open clipboard manager (clipse) |

---

## Waybar

| Shortcut | Action |
|----------|--------|
| `$mod + Shift + Space` | Toggle Waybar visibility |

---

## Mouse

| Shortcut | Action |
|----------|--------|
| `$mod + LMB (drag)` | Move window |
| `$mod + RMB (drag)` | Resize window |

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

---

## Media & Laptop Keys

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
