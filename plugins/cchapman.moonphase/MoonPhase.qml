import QtQuick

// Moon phase bar widget for omarchy-shell.
//
// Draws the current lunar phase as a small disc: a full circle in the bar
// foreground colour with the terminator painted over it, the terminator
// position derived from the age of the moon within the synodic month.
//
// Deliberately plain QtQuick plus only the documented `bar.*` contract from
// shell/plugins/bar/README.md (foreground, background, barSize, vertical,
// run, showTooltip/hideTooltip). It does not import qs.Ui / qs.Commons, so
// it keeps working across omarchy-shell updates that reshuffle internals.
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

    // --- configuration ---------------------------------------------------
    readonly property int discSize: Math.max(8, Number(setting("size", 14)))
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
        canvas.requestPaint()
    }

    function phaseName() {
        var p = phase
        if (p < 0.0169 || p >= 0.9831) return "New moon"
        if (p < 0.2331) return "Waxing crescent"
        if (p < 0.2669) return "First quarter"
        if (p < 0.4831) return "Waxing gibbous"
        if (p < 0.5169) return "Full moon"
        if (p < 0.7331) return "Waning gibbous"
        if (p < 0.7669) return "Last quarter"
        return "Waning crescent"
    }

    readonly property string tipText:
        phaseName() + " · " + Math.round(illum * 100) + "% lit · day "
            + (Math.floor(ageDays) + 1) + " of ~29.5"

    // --- layout ------------------------------------------------------
    implicitWidth: content.implicitWidth + 8
    implicitHeight: barSize
    visible: true

    Component.onCompleted: recompute()

    // The phase barely moves within a day; a repaint every 30 min is plenty
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

        Canvas {
            id: canvas
            width: root.discSize
            height: root.discSize
            anchors.verticalCenter: parent.verticalCenter

            readonly property color litColor: root.bar ? root.bar.foreground : "#e6e6e6"
            readonly property color darkColor: root.bar ? root.bar.background : "#1e1e1e"
            onLitColorChanged: requestPaint()
            onDarkColorChanged: requestPaint()

            onPaint: {
                var ctx = getContext("2d")
                ctx.reset()

                var r = Math.min(width, height) / 2 - 1
                if (r <= 0)
                    return
                var cx = width / 2
                var cy = height / 2

                var p = root.phase
                // Northern hemisphere: waxing moon is lit on the right.
                var waxing = (p < 0.5) !== root.southern
                var cosv = Math.cos(2 * Math.PI * p) // +1 at new, -1 at full
                var k = Math.max(Math.abs(cosv), 0.0001) // terminator x-scale

                // Unlit disc.
                ctx.fillStyle = canvas.darkColor
                ctx.beginPath()
                ctx.arc(cx, cy, r, 0, 2 * Math.PI)
                ctx.fill()

                // Lit hemisphere (the limb side).
                ctx.fillStyle = canvas.litColor
                ctx.beginPath()
                if (waxing)
                    ctx.arc(cx, cy, r, -Math.PI / 2, Math.PI / 2, false)
                else
                    ctx.arc(cx, cy, r, Math.PI / 2, Math.PI * 1.5, false)
                ctx.closePath()
                ctx.fill()

                // Terminator: a circle squashed horizontally to |cos(phase)|,
                // painted unlit for a crescent (carves the lit side back) or
                // lit for a gibbous moon (fills the unlit side in).
                ctx.fillStyle = cosv > 0 ? canvas.darkColor : canvas.litColor
                ctx.save()
                ctx.translate(cx, cy)
                ctx.scale(k, 1)
                ctx.beginPath()
                ctx.arc(0, 0, r, 0, 2 * Math.PI)
                ctx.fill()
                ctx.restore()

                // Faint rim so a near-new moon still reads against a
                // background close to the bar colour.
                ctx.globalAlpha = 0.45
                ctx.strokeStyle = canvas.litColor
                ctx.lineWidth = 1
                ctx.beginPath()
                ctx.arc(cx, cy, r, 0, 2 * Math.PI)
                ctx.stroke()
                ctx.globalAlpha = 1
            }
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
            if (root.clickCommand !== "") {
                root.bar.run(root.clickCommand)
                return
            }
            root.bar.run("notify-send -a Moon "
                + root.sq(root.phaseName()) + " "
                + root.sq(Math.round(root.illum * 100) + "% illuminated — day "
                    + (Math.floor(root.ageDays) + 1) + " of the ~29.5-day cycle"))
        }
    }
}
