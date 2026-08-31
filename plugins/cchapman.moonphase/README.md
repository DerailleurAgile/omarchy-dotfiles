# cchapman.moonphase

A bar widget for [omarchy-shell](https://omarchy.org/manual/shell-plugins/) that
draws the current phase of the moon as a small disc in the Omarchy bar.

- Full circle in the bar foreground colour, terminator painted over it.
- Phase is computed locally from the synodic month (no network), repainted
  every 30 minutes.
- Hover shows the phase name, illuminated fraction, and day of the cycle.
- Click sends a `notify-send` with the same detail, or runs `onClick` if set.

## Settings (`barWidget.schema`)

| key          | type    | default   | meaning                                             |
|--------------|---------|-----------|----------------------------------------------------|
| `size`       | integer | `14`      | disc diameter in px (8–24)                          |
| `hemisphere` | enum    | `north`   | `south` mirrors the lit side                        |
| `showPercent`| boolean | `false`   | print the illuminated `%` next to the disc          |
| `onClick`    | string  | `""`      | shell command on click; empty = notification        |

Set them inline in `~/.config/omarchy/shell.json` under the widget's layout
entry, e.g. `{ "id": "cchapman.moonphase", "size": 16, "showPercent": true }`.

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
