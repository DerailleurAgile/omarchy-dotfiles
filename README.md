# omarchy-dotfiles

Personal [Omarchy](https://omarchy.org/) config, tracked outside `~/.config`
and symlinked into place. Omarchy's own refresh/update tooling writes
*through* symlinks rather than replacing them, so this is safe to keep
alongside a normal Omarchy install.

## Layout

```
hypr/   ~/.config/hypr/*   (Hyprland: keybindings, monitors, input, looks)
bin/    ~/.local/bin/*     (personal scripts)
```

Each file under `hypr/` is symlinked individually from `~/.config/hypr/`
(the directory itself is real, not a symlink). Same pattern for `bin/`,
symlinked from `~/.local/bin/`.

## Setting up on a new machine

```bash
git clone https://github.com/DerailleurAgile/omarchy-dotfiles.git ~/Work/omarchy-dotfiles

for f in ~/Work/omarchy-dotfiles/hypr/*; do
  ln -sf "$f" ~/.config/hypr/"$(basename "$f")"
done
hyprctl reload

mkdir -p ~/.local/bin
for f in ~/Work/omarchy-dotfiles/bin/*; do
  ln -sf "$f" ~/.local/bin/"$(basename "$f")"
done
```

## Notable customizations

### `font-preview` — see installed fonts rendered in themselves

Defined in [`bin/font-preview`](bin/font-preview).

**Why:** Omarchy's own font picker (`omarchy font list` / the Style → Font
menu) prints every font name in the same UI font, so the choices are
indistinguishable at a glance.

**What it does:** a self-contained Python script that shells out to
`fc-list`, then generates and opens a local HTML specimen sheet where each
installed font's name and a sample pangram render *in that font*. Two tabs —
monospace (the fonts `omarchy font set` can target) and every installed
family — plus live search, the current monospace font highlighted, and a
ready-to-copy `omarchy font set "…"` command on each monospace card.

```bash
font-preview            # regenerate + open in the default browser
font-preview --no-open  # just regenerate the HTML file
```

### `font-compare` — see fonts rendered live in real terminal windows

Defined in [`bin/font-compare`](bin/font-compare).

**Why:** `font-preview` (above) is a browser page — good for browsing names
and shapes, but a browser doesn't render exactly like `foot` does, and it
can't show box-drawing, ligatures, or Nerd Font icons the way your actual
prompt uses them. A terminal also only reads its font once at startup —
`omarchy font set` correctly rewrites every terminal's config, but an
already-open window won't reflect it until it's restarted — so there's no
way to preview a font change live inside one running terminal at all.

**What it does:** opens one real `foot` window per font passed in — each
with its font overridden on the command line (`-f`, `-a fontcompare-tag`),
no config file touched — showing a pangram, box-drawing, ligatures, and Nerd
Font icons, then drops into a live shell so you can try your actual prompt.
Windows tile onto your current workspace like any other new window, so
several fonts are visible side by side at once. Re-running closes the
previous batch first.

```bash
font-compare --list                                    # fonts you can pass in
font-compare "CaskaydiaMono Nerd Font" "JetBrainsMono Nerd Font" "Adwaita Mono"
```

Windows are spawned directly (`setsid ... & disown`), not via
`hyprctl dispatch exec` — this machine's Hyprland fork routes `dispatch`
through a Lua config layer where a plain exec string doesn't reliably spawn
a process.

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
