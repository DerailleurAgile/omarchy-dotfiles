import QtQuick
import qs.Commons
import qs.Ui

BarWidget {
  id: root
  moduleName: "omarchy.weather"

  function injectPanel() {
    var target = panelLoader.item
    if (!target) return
    if ("bar" in target) target.bar = root.bar
    if ("settings" in target) target.settings = root.settings
    if ("anchorItem" in target) target.anchorItem = button
    if ("hostWidget" in target) target.hostWidget = root
  }

  function refresh() {
    if (panelLoader.item && panelLoader.item.refresh) panelLoader.item.refresh()
  }

  function togglePanel() {
    if (panelLoader.item && panelLoader.item.toggle) panelLoader.item.toggle()
  }

  // Shape contract for shell.summon/hide/toggle routing (Bar.findPanelWidget
  // requires open/close/opened on the bar-widget root). Open maps to the
  // panel's hotkey path so summoning suppresses the center hover reveal,
  // matching what the old per-plugin IpcHandler did.
  readonly property bool opened: panelLoader.item ? panelLoader.item.opened === true : false

  function open() {
    if (panelLoader.item && panelLoader.item.openFromHotkey) panelLoader.item.openFromHotkey()
  }

  function close() {
    if (panelLoader.item && panelLoader.item.close) panelLoader.item.close()
  }

  // Forwarded so this widget can stand in for the panel as the bar's popout
  // identity: Bar.requestPopout prefers closeForPopoutSwitch over close, and
  // KeyboardPanel reads popoutSwitchClosing back off its owner.
  readonly property bool popoutSwitchClosing: panelLoader.item ? panelLoader.item.popoutSwitchClosing === true : false

  function closeForPopoutSwitch() {
    if (panelLoader.item) panelLoader.item.closeForPopoutSwitch()
  }

  // Omarchy 4.5 ignores BarIconButton.fontSize for size: every glyph is drawn
  // normalized to Style.bar.iconSize (OpticalGlyph.paintedSize). Weather glyphs
  // render visibly smaller than the other bar icons at that size, so scale this
  // widget's glyph up. Drop on re-sync if upstream sizing changes.
  readonly property real iconScale: 1.8
  readonly property real iconNudgeY: 3

  function applyIconScale(item) {
    if (!item) return false
    if (item.paintedSize !== undefined && item.renderedFontSize !== undefined) {
      item.paintedSize = Qt.binding(function() { return Style.bar.iconSize * root.iconScale })
      // The weather glyphs' measured ink runs below the visible shape, so the
      // optical centering leaves them riding high; nudge back down.
      item.transform = [Qt.createQmlObject("import QtQuick; Translate { y: " + root.iconNudgeY + " }", item)]
      return true
    }
    for (var i = 0; i < item.children.length; i++)
      if (applyIconScale(item.children[i])) return true
    return false
  }

  visible: panelLoader.item && panelLoader.item.label !== ""
  implicitWidth: button.implicitWidth
  implicitHeight: button.implicitHeight

  onBarChanged: injectPanel()
  onSettingsChanged: injectPanel()

  Loader {
    id: panelLoader
    active: true
    source: Qt.resolvedUrl("Panel.qml")
    visible: false
    onLoaded: {
      root.injectPanel()
      Qt.callLater(root.injectPanel)
    }
  }

  BarIconButton {
    id: button
    anchors.fill: parent
    bar: root.bar
    text: panelLoader.item ? panelLoader.item.label : ""
    slotSize: Style.bar.statusSlot
    // Bumped from the default Style.bar.iconFont (~13-15px). On a
    // high-density panel (~157 PPI) that default is only ~2.6mm physically —
    // pushed close to the bar's own height (30px) so it actually reads at a
    // glance. The button already fills the full bar height, so this doesn't
    // grow the bar itself.
    // Tooltip suppressed because the panel is the detail view.
    opticalSize: Style.bar.iconCanvas + 14
    tooltipText: ""
    Component.onCompleted: root.applyIconScale(button)

    onPressed: function(b) {
      if (!root.bar) return
      if (b === Qt.RightButton) root.bar.run("omarchy-notification-send \"$(omarchy-weather-status)\"")
      else if (b === Qt.MiddleButton) root.refresh()
      else root.togglePanel()
    }
  }
}
