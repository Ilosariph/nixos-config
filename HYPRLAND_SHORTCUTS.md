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
| `$mod + -` | Shrink window horizontally (–100px) |
| `$mod + =` | Grow window horizontally (+100px) |
| `$mod + Shift + -` | Shrink window vertically (–100px) |
| `$mod + Shift + =` | Grow window vertically (+100px) |
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
| `$mod + .` | Next workspace |
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
| `$mod + Ctrl + V` | Open clipboard manager (clipse) |

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