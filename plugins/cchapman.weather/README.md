# `cchapman.weather`

A **clone of the stock `omarchy.weather`** bar plugin (made with
`omarchy plugin clone omarchy.weather`), tracked here so the one real
customization survives and so update breakage is a visible `git diff`
instead of a mystery.

## The only real customization

`BarWidget.qml` bumps the weather glyph:

```qml
fontSize: 28
opticalSize: Style.bar.iconCanvas + 14
```

Stock is `fontSize: Style.bar.iconFont` (~13). On this ~157 PPI panel the
default glyph is only ~2.6 mm tall, which is unreadable at a glance. This
enlarges only the glyph canvas centred in the widget — the click target
(`slotSize`, 21 px) is unchanged, so the bar itself does not grow.

`manifest.json` differs from stock only in the clone bookkeeping (`id`,
`name`, `omarchy.clonedFrom`). `Model.js` and `Panel.qml` are verbatim
copies of the packaged plugin and carry no personal edits.

## Why it's a clone and not a `shell.json` tweak

The bar has no setting for icon size. Cloning the plugin is the only way
to reach `BarWidget.qml`. A clone also keeps `omarchy plugin list` /
`enable` / `disable` working for it.

## Keeping it in sync after `omarchy update`

Cloned plugins are frozen copies. `omarchy update` moves the packaged
plugin **and the shell APIs it calls** forward; the clone stays behind and
silently breaks. This bit once already: after 4.0.3 the weather panel
opened but could not be closed (whole-session keyboard lock) because
`bar.centerHoverRevealSuppressed` had changed from a writable property to
a `bar.setCenterHoverRevealSuppressed()` method, and the stale `close()`
threw before it reached `controller.hide()`.

After every `omarchy update`, diff the two non-personal files against the
packaged copy:

```bash
diff -u /usr/share/omarchy/shell/plugins/panels/weather/Panel.qml Panel.qml
diff -u /usr/share/omarchy/shell/plugins/panels/weather/Model.js   Model.js
```

If the only differences are packaged-side additions, copy the packaged
file over the tracked one and commit. For `BarWidget.qml`, diff too but
re-apply the `fontSize` / `opticalSize` lines by hand if the packaged
version moved on.

Then **`omarchy restart shell`** — not `omarchy-shell shell rescanPlugins`.
The hot-reload does not reliably pick up a changed cloned *panel*; only a
full shell restart does.

## Verifying without a real bar click

An agent / script can't click the bar, but the panel's whole lifecycle is
reachable over IPC — clean open/close here means the QML is healthy:

```bash
omarchy-shell omarchy.weather open
omarchy-shell omarchy.weather close
omarchy-shell omarchy.weather toggle   # x2
```

(The clone answers on the `omarchy.weather` IPC target, not
`cchapman.weather` — `clonePaths` keeps the built-in id inside the code as
a stable target and the shell routes it via `clonedFrom`.)
