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
