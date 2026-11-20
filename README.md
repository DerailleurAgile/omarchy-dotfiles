# omarchy-dotfiles

Personal [Omarchy](https://omarchy.org/) config, tracked outside `~/.config`
and symlinked into place. Omarchy's own refresh/update tooling writes
*through* symlinks rather than replacing them, so this is safe to keep
alongside a normal Omarchy install.

## Layout

```
hypr/     ~/.config/hypr/*                     (Hyprland: keybindings, monitors, input, looks)
bin/      ~/.local/bin/*                       (personal scripts)
hooks/    ~/.config/omarchy/hooks/<event>.d/*  (omarchy automation hooks)
plugins/  ~/.config/omarchy/plugins/<id>/*     (omarchy-shell plugins)
cliamp/   ~/.config/cliamp/{config.toml,playlists/*}  (cliamp player settings + playlists)
foliate/  ~/.config/com.github.johnfactotum.Foliate/themes/*  (Foliate custom themes)
applications/  ~/.local/share/applications/*   (desktop-entry overrides)
```

Each file is symlinked individually from its target directory (the
directories themselves are real, not symlinks) — `hypr/` from
`~/.config/hypr/`, `bin/` from `~/.local/bin/`, each `hooks/<event>.d/`
subdirectory from the matching `~/.config/omarchy/hooks/<event>.d/`, and each
`plugins/<id>/` subdirectory from the matching
`~/.config/omarchy/plugins/<id>/`. For cliamp, only `config.toml` and the
playlist files are tracked; runtime state (`history.toml`, `resume.json`,
`cliamp.log`, `*.bak`) stays local.

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

for d in ~/Work/omarchy-dotfiles/hooks/*/; do
  event="$(basename "$d")"
  mkdir -p ~/.config/omarchy/hooks/"$event"
  for f in "$d"*; do
    ln -sf "$f" ~/.config/omarchy/hooks/"$event"/"$(basename "$f")"
  done
done

for d in ~/Work/omarchy-dotfiles/plugins/*/; do
  id="$(basename "$d")"
  mkdir -p ~/.config/omarchy/plugins/"$id"
  for f in "$d"*; do
    ln -sf "$f" ~/.config/omarchy/plugins/"$id"/"$(basename "$f")"
  done
  omarchy plugin enable "$id"
done

mkdir -p ~/.config/cliamp/playlists
ln -sf ~/Work/omarchy-dotfiles/cliamp/config.toml ~/.config/cliamp/config.toml
for f in ~/Work/omarchy-dotfiles/cliamp/playlists/*; do
  ln -sf "$f" ~/.config/cliamp/playlists/"$(basename "$f")"
done

mkdir -p ~/.config/com.github.johnfactotum.Foliate/themes
for f in ~/Work/omarchy-dotfiles/foliate/themes/*; do
  ln -sf "$f" ~/.config/com.github.johnfactotum.Foliate/themes/"$(basename "$f")"
done

mkdir -p ~/.local/share/applications
for f in ~/Work/omarchy-dotfiles/applications/*; do
  ln -sf "$f" ~/.local/share/applications/"$(basename "$f")"
done
```

## Notable customizations

### `cchapman.moonphase` — moon phase in the bar

Defined in [`plugins/cchapman.moonphase/`](plugins/cchapman.moonphase/) (see
its own README).

**What it does:** an `omarchy-shell` bar-widget plugin that draws the current
lunar phase as a small disc — a circle in the bar foreground colour with the
terminator painted over it, position derived from the moon's age within the
synodic month. Computed locally (no network), refreshed every 30 minutes.
Hover for the phase name and illuminated fraction; left-click for a popup
with a large rendering of the phase (or a configurable `onClick` command);
right-click for a `notify-send`. Tunables — `style`, `size`, `hemisphere`,
`showPercent`, `onClick` — via the widget's `shell.json` layout entry or the
Style → Bar settings form.

**Why a plugin, not a custom `shell.json` module:** it shows up in
`omarchy plugin list` / `enable` / `disable`, carries its own settings schema,
and only touches the documented `bar.*` contract, so it survives shell
updates.

### `cchapman.weather` — bigger weather glyph in the bar

Defined in [`plugins/cchapman.weather/`](plugins/cchapman.weather/) (see
its own README).

**What it does:** a clone of the stock `omarchy.weather` plugin whose only
real edit is in `BarWidget.qml` — `fontSize: 28` /
`opticalSize: Style.bar.iconCanvas + 14`, up from the stock ~13 px glyph,
which is too small to read on this ~157 PPI panel. Only the glyph canvas
grows; the 21 px click slot and the bar height are unchanged. `Panel.qml`
and `Model.js` are verbatim copies of the packaged plugin.

**Why a clone, not a `shell.json` tweak:** the bar exposes no icon-size
setting, so reaching `BarWidget.qml` needs a clone.

**Maintenance:** unlike `cchapman.moonphase`, a clone does *not* survive
shell updates cleanly — `omarchy update` moves the packaged plugin and the
shell APIs it calls, and the frozen clone breaks silently (this already
cost one whole-session keyboard lock after 4.0.3, when the panel's
`close()` started throwing on a since-removed writable property). After
every `omarchy update`, diff `Panel.qml` / `Model.js` against
`/usr/share/omarchy/shell/plugins/panels/weather/`, copy forward any
packaged-only changes, then `omarchy restart shell` (the plugin hot-reload
does not reliably reload a changed cloned panel). Full procedure in the
plugin's own README.

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

**Staying in sync:** the "current font" highlight is a snapshot taken at
generation time — the page has no way to notice a later font change on its
own. [`hooks/font-set.d/regenerate-font-preview`](hooks/font-set.d/regenerate-font-preview)
regenerates the HTML automatically every time `omarchy font set` (or the
Fonts menu) runs, so the data on disk is always current; an already-open
browser tab still needs its **↺ Reload** button clicked to pick that up,
since a local file can't push updates into an open tab.

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

### `foliate-light` — Foliate with readable highlights and a highlight shortcut

Defined in [`bin/foliate-light`](bin/foliate-light).

**Why:** with the desktop on `prefer-dark`, Foliate 3.3 renders the book
page with dark colors no matter what the in-app Light Style swatch says.
The page is kept light with custom themes whose `dark` colors match their
`light` colors: [`foliate/themes/`](foliate/themes/), which shows up as
Paper / Sepia / Grass **(Light)** in *Font & Layout Settings → Color*. Pick
one of those; the built-in themes always give a dark page in dark mode. Keep
*Invert Colors in Dark Mode* off. But `reader.html` still blends annotation highlights with
`screen` in dark mode, which washes them out on a light page.
Upstream: [foliate#1597](https://github.com/johnfactotum/foliate/issues/1597).

**What it does:** on every launch, extracts two files from Foliate's
gresource, patches them, points `G_RESOURCE_OVERLAYS` at the patched copies
(in `~/.cache/foliate-light/`), and runs Foliate:

- `reader/reader.html`: switches the dark-mode highlight blend from `screen`
  to `multiply`.
- `book-viewer.js`: adds **Ctrl+H** to highlight the current selection.
  Stock Foliate only has a Highlight button in the selection popover. The
  shortcut is attached to that popover, which has keyboard focus while
  open. It uses the last-used highlight color.

It re-extracts every time, so the patches follow Foliate updates. Each patch
applies only if its anchor text appears exactly once; otherwise that file is
skipped (with a message on stderr) and Foliate runs stock for that part.

**Launcher hookup:** it only takes effect if Foliate is started through it.
[`applications/com.github.johnfactotum.Foliate.desktop`](applications/com.github.johnfactotum.Foliate.desktop)
is the system desktop entry with `Exec` pointed at `foliate-light`. It
shadows the packaged entry, so if a Foliate update changes that entry,
regenerate it:

```bash
sed 's|^Exec=foliate |Exec=/home/cchapman/.local/bin/foliate-light |' \
  /usr/share/applications/com.github.johnfactotum.Foliate.desktop \
  > ~/Work/omarchy-dotfiles/applications/com.github.johnfactotum.Foliate.desktop
```

Foliate is single-instance: quit it fully before relaunching, or the new
launch hands off to the running process without the overlay.

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

### Caps Lock as Super (Kano keyboard)

Defined in [`hypr/input.lua`](hypr/input.lua).

**Why:** the Kano wireless keyboard (from the old Raspberry Pi kids' kit)
has no Super key, and Omarchy binds nearly every shortcut to `SUPER`.

**What it does:** sets `input.kb_options` to
`caps:super,shift:both_capslock_cancel`, making Caps Lock an additional
Super modifier. This replaces Omarchy's default `compose:caps`, so Caps
Lock no longer acts as a Compose key.

**Why it survives an update:** `hyprland.lua` loads
`require("default.hypr.omarchy")` (which sets the default `kb_options`)
*before* `require("hypr.input")`, so this override always wins on a
last-write basis. `omarchy update` only touches `/usr/share/omarchy/*`,
never `~/.config/hypr/*` — and every file there is symlinked into this
repo, so any stray write shows up as a `git diff`.

**Maintenance notes:**

- `hypr/hyprland.lua` here is a pinned copy of Omarchy's stock file. If a
  future release rewrites it and you adopt the new version, confirm
  `require("hypr.input")` still loads *after* `require("default.hypr.omarchy")`.
  Spot-check: `diff /usr/share/omarchy/config/hypr/hyprland.lua ~/.config/hypr/hyprland.lua`.
- The `kb_options` string is hardcoded. Omarchy's default appends
  `,grp:alts_toggle` when the primary `kb_layout` is non-Latin; if you
  ever add such a layout, replicate that in [`hypr/input.lua`](hypr/input.lua).
- Failure mode is loud, not silent: if the override ever stops applying,
  Caps Lock simply stops triggering `SUPER` bindings.
