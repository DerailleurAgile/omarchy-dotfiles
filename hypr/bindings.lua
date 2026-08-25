-- Keep only your personal keybinding overrides here. Add new bindings or
-- unbind defaults before replacing them.

-- See current bindings and descriptions:
--   omarchy menu keybindings --print

-- To disable every Omarchy default binding, set this in
-- ~/.config/hypr/hyprland.lua before require("default.hypr.omarchy"), then add
-- only the bindings you want below:
--   omarchy_default_bindings = false

-- To disable all preinstalled app/webapp bindings, set:
--   omarchy_preinstalled_bindings = false

-- Add a new binding.
-- o.bind("SUPER + SHIFT + R", "SSH", "alacritty -e ssh your-server")

-- Change an existing binding by unbinding it first, then binding the key again.
-- This example changes SUPER+SPACE from the launcher to the Omarchy root menu.
-- hl.unbind("SUPER + SPACE")
-- o.bind("SUPER + SPACE", "Omarchy menu", "omarchy-menu toggle root")

-- Disable a default binding without replacing it.
-- hl.unbind("SUPER + SHIFT + B")

-- Logitech MX Keys examples:
-- o.bind("SUPER + SHIFT + S", nil, "omarchy-capture-screenshot")
-- o.bind("SUPER + H", nil, "voxtype record toggle")
-- o.bind("SUPER + PERIOD", nil, "omarchy-shell shell toggle omarchy.emojis")

-- Snap the focused window to exactly the size/position a normal tiled
-- window would have if it were sharing the screen with one sibling (i.e.
-- half width, full height, with the same gaps/border a real tile gets --
-- not edge-to-edge). Dwindle can't leave tiled space blank next to a solo
-- window, so this floats the window to fake it. Press the same key again
-- to un-snap back to a regular full-size tile; press the other bracket to
-- flip it to the opposite side. If a second window opens while one is
-- snapped, it's automatically floated+sized into the other half so the
-- pair looks and behaves like a real split.
do
  local function usable_box(win)
    local mon = win.monitor
    if not mon then
      return nil
    end
    local scale = mon.scale or 1
    local reserved = mon.reserved or { left = 0, top = 0, right = 0, bottom = 0 }
    return {
      x = mon.position.x + reserved.left,
      y = mon.position.y + reserved.top,
      w = (mon.width / scale) - reserved.left - reserved.right,
      h = (mon.height / scale) - reserved.top - reserved.bottom,
    }
  end

  local function as_gap(value)
    if type(value) == "table" then
      return value
    end
    value = value or 0
    return { left = value, top = value, right = value, bottom = value }
  end

  -- Half-screen geometry that matches what dwindle would give this window
  -- if it had exactly one tiled sibling on the requested side.
  local function half_geometry(win, side)
    local box = usable_box(win)
    if not box then
      return nil
    end

    local gaps_out = as_gap(hl.get_config("general.gaps_out"))
    local gaps_in = as_gap(hl.get_config("general.gaps_in"))
    local border = hl.get_config("general.border_size") or 0

    local margin_left = gaps_out.left + border
    local margin_right = gaps_out.right + border
    local margin_top = gaps_out.top + border
    local margin_bottom = gaps_out.bottom + border
    -- Each of the two tiled siblings contributes its own facing gaps_in
    -- edge (plus border) to the total space between them.
    local inner_gap = gaps_in.right + gaps_in.left + 2 * border

    local width = (box.w - margin_left - margin_right - inner_gap) / 2
    local height = box.h - margin_top - margin_bottom
    local y = box.y + margin_top
    local x = (side == "left") and (box.x + margin_left) or (box.x + box.w - margin_right - width)

    return {
      x = math.floor(x + 0.5),
      y = math.floor(y + 0.5),
      w = math.floor(width + 0.5),
      h = math.floor(height + 0.5),
    }
  end

  local SNAP_EPS = 2
  local function approx(a, b)
    return math.abs(a - b) <= SNAP_EPS
  end

  -- Which half (if any) this window is currently snapped to, judged by its
  -- actual geometry rather than any tracked state -- so it self-corrects if
  -- the window gets moved, resized, or the config gets reloaded.
  local function snapped_side(win)
    if not win.floating then
      return nil
    end
    for _, side in ipairs({ "left", "right" }) do
      local g = half_geometry(win, side)
      if g and approx(win.at.x, g.x) and approx(win.at.y, g.y) and approx(win.size.x, g.w) and approx(win.size.y, g.h) then
        return side
      end
    end
    return nil
  end

  -- Floats (if needed) and sizes/positions the *active* window into g.
  -- Callers must ensure their target window is the active one.
  local function apply_half(win, g)
    if not win.floating then
      hl.dispatch(hl.dsp.window.float({ action = "enable" }))
    end
    hl.dispatch(hl.dsp.window.resize({ x = g.w, y = g.h, exact = true }))
    hl.dispatch(hl.dsp.window.move({ x = g.x, y = g.y, exact = true }))
  end

  local function snap_active(side)
    local win = hl.get_active_window()
    if not win then
      return
    end
    if snapped_side(win) == side then
      hl.dispatch(hl.dsp.window.float({ action = "disable" }))
      return
    end
    local g = half_geometry(win, side)
    if g then
      apply_half(win, g)
    end
  end

  o.bind("SUPER + BRACKETLEFT", "Snap window to left half", function()
    snap_active("left")
  end)
  o.bind("SUPER + BRACKETRIGHT", "Snap window to right half", function()
    snap_active("right")
  end)

  -- A newly opened window is the active window at this point, so
  -- apply_half()'s active-window dispatches land on it.
  hl.on("window.open", function(win)
    if not win or not win.workspace then
      return
    end
    local other_side, other_count = nil, 0
    for _, w in ipairs(hl.get_workspace_windows(win.workspace)) do
      if w.address ~= win.address then
        other_count = other_count + 1
        other_side = snapped_side(w) or other_side
      end
    end
    if other_count == 1 and other_side then
      local g = half_geometry(win, other_side == "left" and "right" or "left")
      if g then
        apply_half(win, g)
      end
    end
  end)
end
