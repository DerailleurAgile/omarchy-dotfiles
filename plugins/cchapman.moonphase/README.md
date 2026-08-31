# cchapman.moonphase

A bar widget for [omarchy-shell](https://omarchy.org/manual/shell-plugins/) that
shows the current phase of the moon in the Omarchy bar.

- Two styles: the colour moon glyphs `🌑🌒🌓🌔🌕🌖🌗🌘` (default, eight
  steps, via the system emoji font) or a disc drawn in the bar colour with a
  continuous terminator (`style: "draw"`).
- Phase is computed locally from the synodic month (no network), refreshed
  every 30 minutes.
- Hover shows the phase name, illuminated fraction, and day of the cycle.
- **Left-click** opens a popup (`qs.Ui.PopupCard`) with the phase name,
  illumination, and day of the cycle — plus a large glyph in `emoji` style.
  If `onClick` is set, left-click runs that instead.
- **Right-click** sends a `notify-send` with the phase detail.

## Settings (`barWidget.schema`)

| key          | type    | default   | meaning                                             |
|--------------|---------|-----------|----------------------------------------------------|
| `style`      | enum    | `emoji`   | `emoji` glyphs, or `draw` a disc in the bar colour  |
| `size`       | integer | `0`       | glyph pt size (emoji) / disc px (draw); `0` = auto  |
| `hemisphere` | enum    | `north`   | `south` mirrors the lit side                        |
| `showPercent`| boolean | `false`   | print the illuminated `%` next to the glyph         |
| `onClick`    | string  | `""`      | shell command on click; empty = notification        |

Set them inline in `~/.config/omarchy/shell.json` under the widget's layout
entry, e.g. `{ "id": "cchapman.moonphase", "style": "draw", "size": 16 }`.

The emoji glyphs render in colour and do **not** follow the bar's foreground
colour (that is how colour emoji work); `style: "draw"` is the theme-tinted
option.

## How it works

Everything is one file, `MoonPhase.qml`, a plain `Item` (not `qs.Ui`'s
`BarWidget`). The bar host injects `bar`, `moduleName`, and `settings` into
it by name; the widget only ever reads the documented `bar.*` surface
(`foreground`, `background`, `barSize`, `fontFamily`, `run`,
`showTooltip` / `hideTooltip`), so a shell update that reshuffles internals
does not break it. The one exception is the popup, which uses
`qs.Ui.PopupCard` (and `qs.Commons`' `Style` / `Color`) — the same surface
the shipped third-party OmaOneDrive plugin builds its panel on.

**Phase maths.** `recompute()` takes the days elapsed since a reference new
moon (2000-01-06 18:14 UTC) modulo the mean synodic month (29.530588853 d).
That gives `phase` (0 = new, 0.5 = full), `illum` = `(1 − cos 2π·phase) / 2`,
and `ageDays`. `phaseIndex()` buckets `phase` into the eight named phases
(the quarter/new/full buckets are deliberately narrow, ~±0.6 d). It is a
mean-motion approximation — no lunar anomaly, so it can be a few hours off
the true phase, which is well inside a bucket. A 30-minute `Timer` keeps it
current across a long shell session.

**`MoonDisc`.** An inline `component` (`component MoonDisc: Item { … }`) that
draws the moon from three stacked `Rectangle`s — no `Canvas`, because a
`Canvas` only paints while its window is mapped and never got a frame inside
the popup:

1. **Base circle** — `radius: width/2`, filled with `darkColor` (the unlit
   moon).
2. **Lit hemisphere** — a half-width `Rectangle` with the two corners on the
   lit limb's side rounded to `height/2` (Qt ≥ 6.7 per-corner radius),
   giving a true semicircle whose curved edge shares the base circle's
   centre. Which side is lit comes from `_waxing = (phase < 0.5) !==
   southern`.
3. **Terminator** — a full circle painted `darkColor` for a crescent
   (`cos 2π·phase > 0`) or `litColor` for a gibbous moon, centred and
   squashed horizontally by `transform: Scale { xScale: |cos 2π·phase| }`.
   At the quarters the scale is ~0 so it vanishes and the bare hemisphere
   shows; at new / full it is a full circle that covers the disc.

A faint `litColor` rim (`border`, 45% opacity) sits on top so the silhouette
always reads. `MoonDisc` is fully declarative — it repaints itself through
its property bindings whenever `phase`, `southern`, or the colours change.

The bar uses `MoonDisc` directly. The **popup does not**: even as
Rectangles the disc came out blank inside the `PopupCard` window, so
`style: "draw"` gets a compact text-only card (name · illumination · day)
and only `style: "emoji"` shows a large glyph in the popup.

## Install

Source of truth lives in this repo; it is symlinked into place per-file, the
same pattern the rest of `omarchy-dotfiles` uses:

```sh
mkdir -p ~/.config/omarchy/plugins/cchapman.moonphase
ln -sfn ~/Work/omarchy-dotfiles/plugins/cchapman.moonphase/manifest.json \
        ~/.config/omarchy/plugins/cchapman.moonphase/manifest.json
ln -sfn ~/Work/omarchy-dotfiles/plugins/cchapman.moonphase/MoonPhase.qml \
        ~/.config/omarchy/plugins/cchapman.moonphase/MoonPhase.qml

omarchy plugin validate ~/Work/omarchy-dotfiles/plugins/cchapman.moonphase
omarchy plugin enable cchapman.moonphase right
```

Drag it along the bar to reposition, or move it with `omarchy bar move`.
