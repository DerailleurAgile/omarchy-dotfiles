import QtQuick
import qs.Ui
import qs.Commons

// Moon phase bar widget for omarchy-shell.
//
// Two render styles (see the `style` setting):
//   "emoji" — the Unicode moon-phase glyphs 🌑🌒🌓🌔🌕🌖🌗🌘, rendered in
//             colour via the system emoji font. Eight fixed steps.
//   "draw"  — a disc built from plain Rectangles (base circle + rounded
//             half-disc + a horizontally-scaled circle for the terminator).
//             Takes the bar's foreground colour. No Canvas, so it renders
//             reliably inside the popup window too.
//
// Left-click opens a popup with a large rendering of the current phase (via
// qs.Ui.PopupCard, matching every other bar popup). Right-click sends a
// notification. Everything else sticks to the documented `bar.*` contract
// from shell/plugins/bar/README.md.
Item {
    id: root

    // --- injected by the bar host ------------------------------------------
    property QtObject bar: null
    property string moduleName: "cchapman.moonphase"
    property var settings: ({})

    // Read by Bar.targetTooltipHovered() so bar.showTooltip(root, ...) works.
    property bool tooltipHovered: false

    readonly property int barSize: bar ? bar.barSize : 26

    function setting(name, fallback) {
        var v = settings ? settings[name] : undefined
        return (v === undefined || v === null) ? fallback : v
    }

    // shell-quote for bash -lc (bar.run); Bar has no shellQuote of its own.
    function sq(value) {
        return "'" + String(value === undefined ? "" : value).replace(/'/g, "'\\''") + "'"
    }

    // Called by the bar's popout coordinator when another popup takes over.
    function close() {
        popup.open = false
    }

    // --- configuration ---------------------------------------------------
    readonly property bool useEmoji:
        String(setting("style", "emoji")).toLowerCase() !== "draw"
    // `size` 0 (or unset) means auto: 14px disc / ~0.62·barSize glyph.
    readonly property int sizeOverride: Math.max(0, Number(setting("size", 0)))
    readonly property int drawSize: sizeOverride > 0 ? Math.max(8, sizeOverride) : 14
    readonly property int glyphSize:
        sizeOverride > 0 ? Math.max(8, sizeOverride) : Math.round(barSize * 0.62)
    readonly property bool southern:
        String(setting("hemisphere", "north")).toLowerCase().charAt(0) === "s"
    readonly property bool showPercent: setting("showPercent", false) === true
    readonly property string clickCommand: String(setting("onClick", ""))

    // --- phase maths ---------------------------------------------------
    // Reference new moon: 2000-01-06 18:14 UTC.
    readonly property real synodicDays: 29.530588853
    property real ageDays: 0        // days since the last new moon
    property real phase: 0          // 0..1  (0 = new, 0.5 = full)
    property real illum: 0          // 0..1  illuminated fraction

    function recompute() {
        var refNewMoon = Date.UTC(2000, 0, 6, 18, 14, 0)
        var days = (Date.now() - refNewMoon) / 86400000
        var a = days % synodicDays
        if (a < 0)
            a += synodicDays
        ageDays = a
        phase = a / synodicDays
        illum = (1 - Math.cos(2 * Math.PI * phase)) / 2
    }

    // 0 new · 1 waxing crescent · 2 first quarter · 3 waxing gibbous
    // 4 full · 5 waning gibbous · 6 last quarter · 7 waning crescent
    function phaseIndex() {
        var p = phase
        if (p < 0.0169 || p >= 0.9831) return 0
        if (p < 0.2331) return 1
        if (p < 0.2669) return 2
        if (p < 0.4831) return 3
        if (p < 0.5169) return 4
        if (p < 0.7331) return 5
        if (p < 0.7669) return 6
        return 7
    }

    readonly property var phaseNames: [
        "New moon", "Waxing crescent", "First quarter", "Waxing gibbous",
        "Full moon", "Waning gibbous", "Last quarter", "Waning crescent"]
    readonly property var phaseGlyphs: ["🌑", "🌒", "🌓", "🌔", "🌕", "🌖", "🌗", "🌘"]

    function phaseName() {
        return phaseNames[phaseIndex()]
    }

    // Southern hemisphere sees the lit side mirrored: crescents, quarters and
    // gibbous swap; new and full are unchanged.
    function phaseGlyph() {
        var i = phaseIndex()
        if (southern && i !== 0 && i !== 4)
            i = 8 - i
        return phaseGlyphs[i]
    }

    readonly property string dayText: "day " + (Math.floor(ageDays) + 1) + " of ~29.5"
    readonly property string tipText:
        phaseName() + " · " + Math.round(illum * 100) + "% lit · " + dayText

    // --- the drawn disc, all plain Rectangles -------------------------------
    component MoonDisc: Item {
        id: disc

        property real diameter: 14
        property color litColor: "#e6e6e6"
        property color darkColor: "#1e1e1e"
        property real phase: 0            // 0..1
        property bool southern: false

        implicitWidth: diameter
        implicitHeight: diameter
        width: diameter
        height: diameter

        readonly property real _cos: Math.cos(2 * Math.PI * phase)   // +1 new, -1 full
        readonly property bool _waxing: (phase < 0.5) !== southern
        readonly property real _k: Math.max(Math.abs(_cos), 0.0001)

        // unlit base disc
        Rectangle {
            anchors.fill: parent
            radius: width / 2
            antialiasing: true
            color: disc.darkColor
        }

        // lit hemisphere — a rounded half-disc on the lit limb's side
        Rectangle {
            height: parent.height
            width: parent.width / 2
            x: disc._waxing ? parent.width / 2 : 0
            antialiasing: true
            color: disc.litColor
            topLeftRadius: disc._waxing ? 0 : height / 2
            bottomLeftRadius: disc._waxing ? 0 : height / 2
            topRightRadius: disc._waxing ? height / 2 : 0
            bottomRightRadius: disc._waxing ? height / 2 : 0
        }

        // terminator — a full-height circle squashed horizontally to |cos|,
        // painted unlit for a crescent (carves the lit side back) or lit for a
        // gibbous moon (fills the unlit side in). Centred, so it never leaves
        // the disc.
        Rectangle {
            anchors.centerIn: parent
            width: parent.width
            height: parent.height
            radius: width / 2
            antialiasing: true
            color: disc._cos > 0 ? disc.darkColor : disc.litColor
            transform: Scale {
                origin.x: disc.diameter / 2
                origin.y: disc.diameter / 2
                xScale: disc._k
            }
        }

        // faint rim so the silhouette always reads
        Rectangle {
            anchors.fill: parent
            radius: width / 2
            antialiasing: true
            color: "transparent"
            border.width: 1
            border.color: disc.litColor
            opacity: 0.45
        }
    }

    // --- layout ------------------------------------------------------
    implicitWidth: content.implicitWidth + 8
    implicitHeight: barSize
    visible: true

    Component.onCompleted: recompute()

    // The phase barely moves within a day; a refresh every 30 min is plenty
    // and keeps it correct across a long-running shell session.
    Timer {
        interval: 1800000
        running: true
        repeat: true
        onTriggered: root.recompute()
    }

    Row {
        id: content
        anchors.centerIn: parent
        spacing: 5

        Text {
            visible: root.useEmoji
            anchors.verticalCenter: parent.verticalCenter
            text: root.phaseGlyph()
            // No font.family: let Qt fall back to the colour emoji font for
            // these codepoints. Colour glyphs ignore `color`.
            font.pixelSize: root.glyphSize
        }

        MoonDisc {
            visible: !root.useEmoji
            anchors.verticalCenter: parent.verticalCenter
            diameter: root.drawSize
            phase: root.phase
            southern: root.southern
            litColor: root.bar ? root.bar.foreground : "#e6e6e6"
            darkColor: root.bar ? root.bar.background : "#1e1e1e"
        }

        Text {
            visible: root.showPercent
            anchors.verticalCenter: parent.verticalCenter
            text: Math.round(root.illum * 100) + "%"
            color: root.bar ? root.bar.foreground : "white"
            font.family: root.bar ? root.bar.fontFamily : "monospace"
            font.pixelSize: Math.round(root.barSize * 0.42)
        }
    }

    MouseArea {
        anchors.fill: parent
        hoverEnabled: true
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        onEntered: {
            root.tooltipHovered = true
            if (root.bar)
                root.bar.showTooltip(root, root.tipText)
        }
        onExited: {
            root.tooltipHovered = false
            if (root.bar)
                root.bar.hideTooltip(root)
        }
        onClicked: function (mouse) {
            if (!root.bar)
                return
            if (mouse.button === Qt.RightButton) {
                root.bar.run("notify-send -a Moon "
                    + root.sq(root.phaseName()) + " "
                    + root.sq(Math.round(root.illum * 100) + "% illuminated — " + root.dayText))
                return
            }
            // left button
            if (root.clickCommand !== "") {
                root.bar.run(root.clickCommand)
                return
            }
            root.tooltipHovered = false
            root.bar.hideTooltip(root)
            popup.open = !popup.open
        }
    }

    // --- popup: a large rendering of the current phase ------------------
    PopupCard {
        id: popup
        anchorItem: root
        bar: root.bar
        owner: root
        triggerMode: "click"
        contentWidth: Style.space(196)
        contentHeight: Style.space(200)

        Column {
            anchors.centerIn: parent
            spacing: Style.space(10)

            Item {
                width: Style.space(96)
                height: Style.space(96)
                anchors.horizontalCenter: parent.horizontalCenter

                Text {
                    visible: root.useEmoji
                    anchors.centerIn: parent
                    text: root.phaseGlyph()
                    font.pixelSize: Style.space(84)
                }

                MoonDisc {
                    visible: !root.useEmoji
                    anchors.centerIn: parent
                    diameter: Style.space(92)
                    phase: root.phase
                    southern: root.southern
                    litColor: Color.popups.text
                    // tint the card background toward the text colour so the
                    // unlit side is always visible, even at new moon
                    darkColor: Qt.tint(Color.popups.background,
                        Qt.rgba(Color.popups.text.r, Color.popups.text.g,
                                Color.popups.text.b, 0.14))
                }
            }

            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: root.phaseName()
                color: Color.popups.text
                font.family: Style.font.family
                font.pixelSize: Style.font.title
                font.bold: true
            }

            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: Math.round(root.illum * 100) + "% illuminated"
                color: Color.popups.text
                font.family: Style.font.family
                font.pixelSize: Style.font.body
                opacity: 0.85
            }

            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: root.dayText
                color: Color.popups.text
                font.family: Style.font.family
                font.pixelSize: Style.font.body
                opacity: 0.85
            }
        }
    }
}
