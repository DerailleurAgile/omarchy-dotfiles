# omarchy-dotfiles

Personal [Omarchy](https://omarchy.org/) config, tracked outside `~/.config`
and symlinked into place. Omarchy's own refresh/update tooling writes
*through* symlinks rather than replacing them, so this is safe to keep
alongside a normal Omarchy install.

## Layout

```
hypr/   ~/.config/hypr/*   (Hyprland: keybindings, monitors, input, looks)
```

Each file under `hypr/` is symlinked individually from `~/.config/hypr/`
(the directory itself is real, not a symlink).

## Setting up on a new machine

```bash
git clone https://github.com/DerailleurAgile/omarchy-dotfiles.git ~/Work/omarchy-dotfiles
for f in ~/Work/omarchy-dotfiles/hypr/*; do
  ln -sf "$f" ~/.config/hypr/"$(basename "$f")"
done
hyprctl reload
```

## Notable customizations

### Window half-snapping (`SUPER+[` / `SUPER+]`)

Defined in [`hypr/bindings.lua`](hypr/bindings.lua).

**What it does:** snaps the focused window to exactly half the screen,
sized and positioned the way a real two-window tiled layout would look —
same gaps, same border, same height a tile normally gets — not a
full-height edge-to-edge float.

```
 SUPER+[                    SUPER+]
┌─────────┬─────────┐      ┌─────────┬─────────┐
│         │         │      │         │         │
│ snapped │  empty  │      │  empty  │ snapped │
│  left   │         │      │         │  right  │
│         │         │      │         │         │
└─────────┴─────────┘      └─────────┴─────────┘
```

**Keybindings:**

| Key | Action |
| --- | --- |
| `SUPER + [` | Snap the focused window to the left half |
| `SUPER + ]` | Snap the focused window to the right half |

**How it behaves:**

- Press the bracket for the side a window is *already* snapped to → it
  un-snaps back to a regular, full-size tile.
- Press the *other* bracket → it flips straight to the opposite side.
- Open a second window while one is snapped → the new window is
  automatically floated and sized into the remaining half, so the pair
  looks and behaves like a genuine split-screen tile.

**Why it's a float, not a real tile:** Hyprland's dwindle layout can't
leave a solo window's sibling space blank — a lone tiled window always
fills its whole container, there's no "half tile, half empty" in the
tiling tree. So this floats the window instead, computing the exact
geometry (`gaps_out` + `gaps_in` + `border_size`) that a real dwindle
split would produce, so it's visually indistinguishable from one. A
`window.open` hook then floats+mirrors any newly opened window into the
other half whenever exactly one snapped window already owns the
workspace, which is what makes the second window "tile as expected"
instead of just covering the first one full-screen.
