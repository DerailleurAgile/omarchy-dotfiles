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

- `hypr/bindings.lua` — `SUPER+[` / `SUPER+]` snap the focused window to
  a half-width tile (left/right), matching normal dwindle-tile sizing
  rather than a naive full-height float. Press the same bracket again to
  return to a regular full-size tile, or the other bracket to flip sides.
  Opening a second window while one is snapped auto-fills the other half.
