//@ pragma UseQApplication
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import Quickshell.Services.Mpris
import Quickshell.Services.Pipewire
import Quickshell.Services.UPower
import Quickshell.Services.SystemTray
import Quickshell.Bluetooth
import Quickshell.Io
import QtQuick
import QtQuick.Layouts
import QtQuick.Effects

ShellRoot {
    id: root

    PwObjectTracker {
        objects: Pipewire.defaultAudioSink ? [Pipewire.defaultAudioSink] : []
    }

    // ── Matugen colors ────────────────────────────────────────────
    property color cPrimary:       "#ffb3b4"
    property color cOnPrimary:     "#690005"
    property color cSurface:       "#1a1111"
    property color cSurfaceCont:   "#2e2020"
    property color cSurfaceContHi: "#392828"
    property color cOnSurface:     "#f0dede"
    property color cOnSurfaceVar:  "#d8bfbf"
    property color cSecondary:     "#e6bfbf"
    property color cTertiary:      "#e5c18d"
    property color cError:         "#ffb4ab"
    property color cOutline:       "#a08c8c"

    // Read matugen colors from hyprland colors.conf (format: $color_X = rgba(rrggbbff))
    Process {
        id: colorLoader; running: true
        command: ["sh", "-c", "cat ~/.config/hypr/colors.conf"]
        stdout: SplitParser {
            onRead: data => {
                var m = data.match(/\$color_(\w+)\s*=\s*rgba\(([0-9a-f]{6})/)
                if (!m) return
                var hex = "#" + m[2]
                switch (m[1]) {
                    case "primary":   root.cPrimary   = hex; break
                    case "surface":   root.cSurface   = hex; break
                    case "secondary": root.cSecondary = hex; break
                    case "tertiary":  root.cTertiary  = hex; break
                    case "error":     root.cError     = hex; break
                    case "outline":   root.cOutline   = hex; break
                }
            }
        }
    }
    Process {
        id: colorLoaderExt; running: true
        command: ["sh", "-c", "grep -E '^(foreground|background)=' ~/.config/foot/colors 2>/dev/null"]
        stdout: SplitParser {
            onRead: data => {
                var m = data.match(/^(\w+)=([0-9a-f]{6})/)
                if (!m) return
                if (m[1] === "foreground") { root.cOnSurface = "#" + m[2]; root.cOnSurfaceVar = "#" + m[2] }
                if (m[1] === "background") { root.cSurfaceCont = "#" + m[2]; root.cSurfaceContHi = "#" + m[2] }
            }
        }
    }

    // ── Global state ──────────────────────────────────────────────
    property real   brightness:  0.5
    property string networkName: ""
    property string layoutName:  "EN"
    property int    batPercent:  100
    property bool   batCharging: false
    property bool   wifiOpen:    false
    property bool   btOpen:      false
    property var    currentPlayer: Mpris.players.values.length > 0 ? Mpris.players.values[0] : null
    property bool   playerPlaying: currentPlayer !== null && currentPlayer.playbackState === MprisPlaybackState.Playing

    Timer { interval: 5000;  running: true; repeat: true; onTriggered: brightnessProc.running = true }
    Timer { interval: 15000; running: true; repeat: true; onTriggered: netProc.running      = true }
    Timer { interval: 10000; running: true; repeat: true; onTriggered: batProc.running = true }

    Process {
        id: brightnessProc; running: true
        command: ["sh", "-c", "brightnessctl | grep -oP '\\(\\K[0-9]+(?=%)' | head -1"]
        stdout: SplitParser {
            onRead: data => { var v = parseFloat(data.trim()); if (!isNaN(v)) root.brightness = v / 100 }
        }
    }

    Process {
        id: netProc; running: true
        command: ["sh", "-c", "nmcli -t -f active,ssid dev wifi 2>/dev/null | grep '^yes:' | cut -d: -f2 | head -1"]
        stdout: SplitParser { onRead: data => root.networkName = data.trim() }
    }

    // Battery: read from /sys directly (UPower DisplayDevice lies when charging)
    Process {
        id: batProc; running: true
        command: ["sh", "-c", "echo $(cat /sys/class/power_supply/BAT0/capacity 2>/dev/null || echo 100) $(cat /sys/class/power_supply/BAT0/status 2>/dev/null || echo Unknown)"]
        stdout: SplitParser {
            onRead: data => {
                var parts = data.trim().split(" ")
                if (parts.length >= 2) {
                    root.batPercent  = parseInt(parts[0]) || 0
                    root.batCharging = parts[1] === "Charging" || parts[1] === "Full"
                }
            }
        }
    }

    // Layout: find main keyboard name on init, then use rawEvent for instant updates
    property string _mainKbName: ""
    property string _jsonBuf: ""

    Process {
        id: layoutInitProc
        running: true
        command: ["hyprctl", "-j", "devices"]
        stdout: SplitParser {
            onRead: data => root._jsonBuf += data
        }
        onExited: {
            try {
                var parsed = JSON.parse(root._jsonBuf)
                var kbs = parsed["keyboards"] || []
                var main = kbs.find(k => k.main === true) || kbs.find(k => k.name && k.name.indexOf("virtual") < 0) || kbs[0]
                if (main) {
                    root._mainKbName = main.name || ""
                    root.layoutName = main.active_keymap.indexOf("Russian") >= 0 ? "RU" : "EN"
                }
            } catch(e) {}
            root._jsonBuf = ""
        }
    }

    Connections {
        target: Hyprland
        function onRawEvent(event) {
            if (event.name !== "activelayout") return
            var comma = event.data.indexOf(",")
            if (comma < 0) return
            var kb  = event.data.substring(0, comma)
            var lay = event.data.substring(comma + 1)
            // Only update from the main keyboard (or any non-mouse keyboard if main not found)
            if (root._mainKbName && kb !== root._mainKbName) return
            root.layoutName = lay.indexOf("Russian") >= 0 ? "RU" : "EN"
        }
    }

    Process { id: brightnessSet }

    // ── Pill component ────────────────────────────────────────────
    component Pill: Rectangle {
        id: pill
        property string icon:      ""
        property string svg:       ""
        property string label:     ""
        property color  iconColor: root.cOnSurface
        property bool   hoverable: true
        height: 28; implicitWidth: pr.implicitWidth + 16
        radius: height / 2
        color: Qt.rgba(root.cSurfaceCont.r, root.cSurfaceCont.g, root.cSurfaceCont.b, 0.90)
        border.color: Qt.rgba(root.cPrimary.r, root.cPrimary.g, root.cPrimary.b, hoverable && pma.containsMouse ? 0.50 : 0.22)
        border.width: 1
        MouseArea { id: pma; anchors.fill: parent; hoverEnabled: pill.hoverable }
        Rectangle { anchors.fill: parent; radius: parent.radius; color: Qt.rgba(root.cPrimary.r, root.cPrimary.g, root.cPrimary.b, pma.containsMouse && pill.hoverable ? 0.06 : 0) }
        RowLayout {
            id: pr; anchors.centerIn: parent; spacing: 5
            // SVG icon with color tinting
            Item {
                width: 16; height: 16
                visible: pill.svg !== ""
                Image {
                    id: svgImg; anchors.fill: parent
                    source: pill.svg; smooth: true; mipmap: true
                }
                MultiEffect {
                    source: svgImg; anchors.fill: svgImg
                    colorization: 1.0
                    colorizationColor: pill.iconColor
                }
            }
            // Fallback text icon (nerd font)
            Text { text: pill.icon; font.family: "JetBrainsMono Nerd Font Mono"; font.pixelSize: 14; color: pill.iconColor; visible: pill.icon !== "" && pill.svg === "" }
            Text { text: pill.label; font.family: "JetBrainsMono Nerd Font Mono"; font.pixelSize: 14; color: root.cOnSurface; visible: pill.label !== "" }
        }
    }

    // ── Top bar ───────────────────────────────────────────────────
    PanelWindow {
        id: bar
        anchors { top: true; left: true; right: true }
        implicitHeight: 44
        color: "transparent"
        exclusionMode: ExclusionMode.Normal
        WlrLayershell.exclusiveZone: 44
        WlrLayershell.layer: WlrLayer.Top
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

        Rectangle {
            anchors.fill: parent
            color: root.cSurface
            Rectangle {
                anchors { bottom: parent.bottom; left: parent.left; right: parent.right }
                height: 1; color: Qt.rgba(root.cPrimary.r, root.cPrimary.g, root.cPrimary.b, 0.12)
            }

            RowLayout {
                anchors { fill: parent; leftMargin: 12; rightMargin: 12 }
                spacing: 0

                // ── LEFT: Workspaces + Player ─────────────────────
                RowLayout {
                    spacing: 6

                    // Workspaces: always 1-5, plus any active workspace above 5
                    RowLayout {
                        spacing: 3
                        Repeater {
                            model: {
                                var ids = [1, 2, 3, 4, 5]
                                for (var i = 0; i < Hyprland.workspaces.values.length; i++) {
                                    var id = Hyprland.workspaces.values[i].id
                                    if (id > 5 && ids.indexOf(id) < 0) ids.push(id)
                                }
                                ids.sort((a,b) => a - b)
                                return ids
                            }
                            delegate: Item {
                                required property int modelData
                                property var ws: {
                                    for (var i = 0; i < Hyprland.workspaces.values.length; i++)
                                        if (Hyprland.workspaces.values[i].id === modelData)
                                            return Hyprland.workspaces.values[i]
                                    return null
                                }
                                property bool focused:  ws ? ws.focused : false
                                property bool occupied: ws ? ws.clientCount > 0 : false

                                implicitWidth: wsRect.width + 2
                                implicitHeight: bar.implicitHeight

                                Rectangle {
                                    id: wsRect
                                    anchors.verticalCenter: parent.verticalCenter
                                    width: focused ? 30 : occupied ? 24 : 20
                                    height: 24; radius: 6
                                    color: focused ? Qt.rgba(root.cPrimary.r, root.cPrimary.g, root.cPrimary.b, 0.22)
                                           : occupied ? Qt.rgba(root.cPrimary.r, root.cPrimary.g, root.cPrimary.b, 0.08) : "transparent"
                                    border.color: Qt.rgba(root.cPrimary.r, root.cPrimary.g, root.cPrimary.b, focused ? 0.55 : 0.18)
                                    border.width: 1
                                    Behavior on width { NumberAnimation { duration: 120 } }
                                    Text {
                                        anchors.centerIn: parent; text: modelData
                                        font.family: "JetBrainsMono Nerd Font Mono"; font.pixelSize: 12; font.bold: focused
                                        color: focused ? root.cPrimary : root.cOnSurfaceVar
                                    }
                                }
                                MouseArea {
                                    anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                                    onClicked: Hyprland.dispatch("workspace " + modelData)
                                }
                            }
                        }
                    }

                    // Separator
                    Rectangle { width: 1; height: 20; color: Qt.rgba(root.cPrimary.r, root.cPrimary.g, root.cPrimary.b, 0.15); visible: root.currentPlayer !== null }

                    // Player pill
                    Item {
                        id: playerSection
                        visible: root.currentPlayer !== null
                        implicitHeight: bar.implicitHeight
                        implicitWidth: visible ? playerPill.implicitWidth + 4 : 0

                        Rectangle {
                            id: playerPill
                            anchors.verticalCenter: parent.verticalCenter
                            height: 28; implicitWidth: playerRow.implicitWidth + 16
                            radius: height / 2
                            color: Qt.rgba(root.cSurfaceCont.r, root.cSurfaceCont.g, root.cSurfaceCont.b, 0.90)
                            border.color: Qt.rgba(root.cPrimary.r, root.cPrimary.g, root.cPrimary.b, playerMa.containsMouse ? 0.30 : 0.14); border.width: 1
                            Rectangle { anchors.fill: parent; radius: parent.radius; color: Qt.rgba(root.cPrimary.r, root.cPrimary.g, root.cPrimary.b, playerMa.containsMouse ? 0.06 : 0) }
                            MouseArea {
                                id: playerMa; anchors.fill: parent; hoverEnabled: true
                                acceptedButtons: Qt.MiddleButton
                                onClicked: { if (root.currentPlayer) root.currentPlayer.togglePlaying() }
                                onEntered: playerWin.onEnter()
                                onExited:  playerWin.onLeave()
                            }
                            RowLayout {
                                id: playerRow; anchors.centerIn: parent; spacing: 6
                                Text {
                                    text: root.playerPlaying ? "󰐊" : "󰏤"
                                    font.family: "JetBrainsMono Nerd Font Mono"; font.pixelSize: 13; color: root.cPrimary
                                }
                                Text {
                                    text: {
                                        var p = root.currentPlayer; if (!p) return ""
                                        var t = p.trackTitle || "", a = p.trackArtist || ""
                                        var s = a ? a + " — " + t : t
                                        return s.length > 35 ? s.slice(0, 32) + "…" : s
                                    }
                                    font.family: "JetBrainsMono Nerd Font Mono"; font.pixelSize: 13; color: root.cOnSurface
                                }
                            }
                        }
                    }
                }

                Item { Layout.fillWidth: true }
                Item { Layout.fillWidth: true }

                // ── RIGHT modules ─────────────────────────────────
                RowLayout {
                    spacing: 3

                    // Volume
                    Pill {
                        property var sink: Pipewire.defaultAudioSink
                        property real vol: sink && sink.audio ? Math.min(sink.audio.volume, 1.5) : 0
                        property bool muted: sink && sink.audio ? sink.audio.muted : false
                        svg: muted ? Qt.resolvedUrl("icons/speaker-mute-filled.svg")
                                : vol > 0.5 ? Qt.resolvedUrl("icons/speaker-2-filled.svg")
                                : vol > 0.0 ? Qt.resolvedUrl("icons/speaker-1.svg")
                                : Qt.resolvedUrl("icons/speaker-0.svg")
                        label: muted ? "mute" : Math.round(vol * 100) + "%"
                        iconColor: muted ? "#666" : root.cTertiary
                        WheelHandler {
                            acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
                            onWheel: ev => {
                                var s = Pipewire.defaultAudioSink
                                if (s && s.audio) s.audio.volume = Math.max(0, Math.min(1.5, s.audio.volume + (ev.angleDelta.y > 0 ? 0.05 : -0.05)))
                            }
                        }
                        MouseArea {
                            anchors.fill: parent; acceptedButtons: Qt.MiddleButton
                            onClicked: { var s = Pipewire.defaultAudioSink; if (s && s.audio) s.audio.muted = !s.audio.muted }
                        }
                    }

                    // Brightness
                    Pill {
                        svg: Qt.resolvedUrl("icons/weather-sunny-filled.svg")
                        label: Math.round(root.brightness * 100) + "%"
                        iconColor: root.cTertiary
                        WheelHandler {
                            acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
                            onWheel: ev => {
                                brightnessSet.command = ["brightnessctl", "s", ev.angleDelta.y > 0 ? "5%+" : "5%-"]
                                brightnessSet.running = true
                                Qt.callLater(() => { brightnessProc.running = false; brightnessProc.running = true })
                            }
                        }
                    }

                    // Battery
                    Pill {
                        id: batPill
                        property int  pct:      root.batPercent
                        property bool charging: root.batCharging

                        svg: {
                            if (charging) return pct >= 100 ? Qt.resolvedUrl("icons/battery-full.svg") : Qt.resolvedUrl("icons/battery-charge.svg")
                            if (pct > 80) return Qt.resolvedUrl("icons/battery-8.svg")
                            if (pct > 60) return Qt.resolvedUrl("icons/battery-6.svg")
                            if (pct > 40) return Qt.resolvedUrl("icons/battery-4.svg")
                            if (pct > 20) return Qt.resolvedUrl("icons/battery-2.svg")
                            return Qt.resolvedUrl("icons/battery-0.svg")
                        }
                        label: pct + "%"
                        iconColor: charging ? "#a6e3a1" : pct > 30 ? "#a6e3a1" : "#f38ba8"

                        MouseArea { id: batHover; anchors.fill: parent; hoverEnabled: true }
                    }

                    // Power profile
                    Pill {
                        id: ppPill
                        svg: {
                            switch (PowerProfiles.profile) {
                                case PowerProfile.PowerSaver:  return Qt.resolvedUrl("icons/leaf-two-filled.svg")
                                case PowerProfile.Performance: return Qt.resolvedUrl("icons/fire-filled.svg")
                                default:                       return Qt.resolvedUrl("icons/power-filled.svg")
                            }
                        }
                        label: {
                            switch (PowerProfiles.profile) {
                                case PowerProfile.PowerSaver:  return "saver"
                                case PowerProfile.Performance: return "perf"
                                default:                       return "bal"
                            }
                        }
                        iconColor: {
                            switch (PowerProfiles.profile) {
                                case PowerProfile.PowerSaver:  return root.cTertiary
                                case PowerProfile.Performance: return root.cError
                                default:                       return root.cSecondary
                            }
                        }
                        MouseArea {
                            anchors.fill: parent
                            onClicked: {
                                if (PowerProfiles.hasPerformanceProfile) {
                                    switch (PowerProfiles.profile) {
                                        case PowerProfile.PowerSaver:  PowerProfiles.profile = PowerProfile.Balanced;    break
                                        case PowerProfile.Balanced:    PowerProfiles.profile = PowerProfile.Performance; break
                                        case PowerProfile.Performance: PowerProfiles.profile = PowerProfile.PowerSaver;  break
                                    }
                                } else {
                                    PowerProfiles.profile = PowerProfiles.profile === PowerProfile.Balanced
                                        ? PowerProfile.PowerSaver : PowerProfile.Balanced
                                }
                            }
                        }
                    }

                    // Bluetooth pill
                    Pill {
                        property bool btOn: Bluetooth.defaultAdapter?.enabled ?? false
                        property bool btConn: Bluetooth.devices.values.some(d => d.connected)
                        svg: btOn ? (btConn ? Qt.resolvedUrl("icons/bluetooth-connected-filled.svg")
                                            : Qt.resolvedUrl("icons/bluetooth-filled.svg"))
                                  : Qt.resolvedUrl("icons/bluetooth-disabled-filled.svg")
                        label: {
                            if (!btOn) return "off"
                            var conn = Bluetooth.devices.values.filter(d => d.connected)
                            return conn.length > 0 ? conn[0].name.slice(0, 10) : ""
                        }
                        iconColor: btOn ? (btConn ? root.cPrimary : root.cSecondary) : "#555"
                        MouseArea { anchors.fill: parent; onClicked: root.btOpen = !root.btOpen }
                    }

                    // Network — click to open WiFi menu
                    Pill {
                        svg: root.networkName ? Qt.resolvedUrl("icons/wifi-2-filled.svg") : Qt.resolvedUrl("icons/wifi-4-filled.svg")
                        label: root.networkName.length > 12 ? root.networkName.slice(0, 11) + "…" : root.networkName
                        iconColor: root.wifiOpen ? root.cPrimary : (root.networkName ? root.cSecondary : "#555")
                        hoverable: true
                        MouseArea {
                            anchors.fill: parent
                            onClicked: root.wifiOpen = !root.wifiOpen
                        }
                    }

                    // Tray pill
                    Rectangle {
                        visible: SystemTray.items.values.length > 0
                        height: 28
                        implicitWidth: trayRow.implicitWidth + 12
                        radius: height / 2
                        color: Qt.rgba(root.cSurfaceCont.r, root.cSurfaceCont.g, root.cSurfaceCont.b, 0.90)
                        border.color: Qt.rgba(root.cPrimary.r, root.cPrimary.g, root.cPrimary.b, 0.14); border.width: 1

                        RowLayout {
                            id: trayRow
                            anchors.centerIn: parent
                            spacing: 2

                            Repeater {
                                model: SystemTray.items.values
                                delegate: Item {
                                    id: trayItem
                                    required property SystemTrayItem modelData
                                    width: 20; height: 20

                                    Image {
                                        anchors.centerIn: parent
                                        width: 14; height: 14
                                        source: trayItem.modelData.icon
                                        smooth: true; mipmap: true
                                    }

                                    QsMenuAnchor {
                                        id: trayMenu
                                        menu: trayItem.modelData.menu
                                        anchor.item: trayItem
                                        anchor.gravity: Edges.Bottom
                                        anchor.edges: Edges.Bottom
                                        anchor.adjustment: PopupAdjustment.SlideX
                                    }

                                    MouseArea {
                                        anchors.fill: parent
                                        acceptedButtons: Qt.LeftButton | Qt.RightButton
                                        onClicked: ev => {
                                            if (ev.button === Qt.LeftButton)
                                                trayItem.modelData.activate()
                                            else if (trayItem.modelData.hasMenu)
                                                trayMenu.open()
                                        }
                                    }
                                }
                            }
                        }
                    }

                    // Language
                    Pill { icon: ""; label: root.layoutName; iconColor: root.cPrimary; implicitWidth: 42; hoverable: false }
                }
            }

            // ── Clock centered overlay ────────────────────────────
            Item {
                anchors.centerIn: parent
                width: clockPill.implicitWidth
                height: bar.implicitHeight

                Rectangle {
                    id: clockPill
                    anchors.verticalCenter: parent.verticalCenter
                    height: 28; implicitWidth: clockRow.implicitWidth + 16
                    radius: height / 2
                    color: Qt.rgba(root.cSurfaceCont.r, root.cSurfaceCont.g, root.cSurfaceCont.b, 0.90)
                    border.color: Qt.rgba(root.cPrimary.r, root.cPrimary.g, root.cPrimary.b, clkMa.containsMouse ? 0.30 : 0.14); border.width: 1
                    Rectangle { anchors.fill: parent; radius: parent.radius; color: Qt.rgba(root.cPrimary.r, root.cPrimary.g, root.cPrimary.b, clkMa.containsMouse ? 0.06 : 0) }
                    MouseArea { id: clkMa; anchors.fill: parent; hoverEnabled: true }
                    RowLayout {
                        id: clockRow; anchors.centerIn: parent; spacing: 8
                        Text {
                            font.family: "JetBrainsMono Nerd Font Mono"; font.pixelSize: 14; font.weight: Font.Medium; color: root.cOnSurface
                            Timer { interval: 1000; running: true; repeat: true; onTriggered: parent.text = Qt.formatDateTime(new Date(), "HH:mm") }
                            Component.onCompleted: text = Qt.formatDateTime(new Date(), "HH:mm")
                        }
                        Text { text: "·"; font.pixelSize: 12; color: Qt.rgba(root.cOnSurface.r, root.cOnSurface.g, root.cOnSurface.b, 0.30) }
                        Text {
                            font.family: "JetBrainsMono Nerd Font Mono"; font.pixelSize: 12; color: Qt.rgba(root.cOnSurface.r, root.cOnSurface.g, root.cOnSurface.b, 0.60)
                            Timer { interval: 60000; running: true; repeat: true; onTriggered: parent.text = Qt.formatDateTime(new Date(), "ddd d MMM") }
                            Component.onCompleted: text = Qt.formatDateTime(new Date(), "ddd d MMM")
                        }
                    }
                }
            }
        }
    }

    // ── Battery tooltip popup ─────────────────────────────────────
    PanelWindow {
        id: batTooltipWin
        visible: batHover.containsMouse && batTipText !== ""
        property string batTipText: {
            if (batPill.charging) return batPill.pct >= 100 ? "Fully charged" : "Charging · " + batPill.pct + "%"
            return batPill.pct + "% remaining"
        }
        anchors { top: true; right: true }
        margins { top: 48; right: 140 }
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
        exclusionMode: ExclusionMode.Ignore
        color: "transparent"
        implicitWidth: batTipLabel.implicitWidth + 20
        implicitHeight: batTipLabel.implicitHeight + 12

        Rectangle {
            anchors.fill: parent; radius: 8
            color: root.cSurface
            border.color: Qt.rgba(root.cPrimary.r, root.cPrimary.g, root.cPrimary.b, 0.22); border.width: 1
            Text {
                id: batTipLabel; anchors.centerIn: parent
                text: batTooltipWin.batTipText
                font.family: "JetBrainsMono Nerd Font Mono"; font.pixelSize: 12; color: root.cOnSurface
            }
        }
    }


    // ── Bluetooth popup ───────────────────────────────────────────
    BluetoothPopup {
        visible: root.btOpen
        cSurface:      root.cSurface
        cPrimary:      root.cPrimary
        cOnSurface:    root.cOnSurface
        cOnSurfaceVar: root.cOnSurfaceVar
        cError:        root.cError
    }

    // ── WiFi popup ────────────────────────────────────────────────
    WifiPopup {
        id: wifiPopup
        visible: root.wifiOpen
        cSurface:      root.cSurface
        cPrimary:      root.cPrimary
        cOnSurface:    root.cOnSurface
        cOnSurfaceVar: root.cOnSurfaceVar
        cError:        root.cError
    }

    // ── Player popup ──────────────────────────────────────────────
    PanelWindow {
        id: playerWin
        property bool _show: false
        visible: root.currentPlayer !== null && _show

        Timer {
            id: playerHideTimer
            interval: 250
            onTriggered: playerWin._show = false
        }

        function onEnter() { playerHideTimer.stop(); _show = true }
        function onLeave() { playerHideTimer.restart() }
        anchors { top: true; left: true }
        margins { top: 48; left: 12 }
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
        exclusionMode: ExclusionMode.Ignore
        color: "transparent"
        implicitWidth: 300; implicitHeight: 175

        // Force position update while playing
        Timer {
            interval: 1000; running: root.playerPlaying; repeat: true
            onTriggered: { if (root.currentPlayer) root.currentPlayer.positionChanged() }
        }

        MouseArea {
            id: popupMa; anchors.fill: parent; hoverEnabled: true
            onEntered: playerWin.onEnter()
            onExited:  playerWin.onLeave()
        }

        Rectangle {
            anchors.fill: parent; radius: 14
            color: root.cSurface
            border.color: Qt.rgba(root.cPrimary.r, root.cPrimary.g, root.cPrimary.b, 0.22); border.width: 1

            ColumnLayout {
                anchors { fill: parent; margins: 18 }
                spacing: 12

                ColumnLayout {
                    spacing: 3
                    Text {
                        Layout.fillWidth: true; elide: Text.ElideRight
                        text: root.currentPlayer ? root.currentPlayer.trackTitle : ""
                        color: root.cOnSurface; font.pixelSize: 15; font.weight: Font.Medium
                        font.family: "JetBrainsMono Nerd Font Mono"
                    }
                    Text {
                        Layout.fillWidth: true; elide: Text.ElideRight
                        text: root.currentPlayer ? (root.currentPlayer.trackArtist || "") : ""
                        color: root.cOnSurfaceVar; font.pixelSize: 12; font.family: "JetBrainsMono Nerd Font Mono"
                    }
                }

                ColumnLayout {
                    spacing: 4
                    Rectangle {
                        Layout.fillWidth: true; height: 4; radius: 2
                        color: Qt.rgba(root.cPrimary.r, root.cPrimary.g, root.cPrimary.b, 0.18)
                        Rectangle {
                            height: parent.height; radius: 2; color: root.cPrimary
                            width: {
                                var p = root.currentPlayer
                                if (!p || p.length <= 0) return 0
                                return Math.max(8, parent.parent.width * Math.min(1, p.position / p.length))
                            }
                            Behavior on width { NumberAnimation { duration: 1000 } }
                        }
                    }
                    RowLayout {
                        Text {
                            text: { var p = root.currentPlayer; if (!p) return "0:00"; var s=Math.floor(p.position); return Math.floor(s/60)+":"+(s%60<10?"0":"")+s%60 }
                            color: "#7a6060"; font.pixelSize: 11; font.family: "JetBrainsMono Nerd Font Mono"
                        }
                        Item { Layout.fillWidth: true }
                        Text {
                            text: { var p = root.currentPlayer; if (!p||p.length<=0) return ""; var s=Math.floor(p.length); return Math.floor(s/60)+":"+(s%60<10?"0":"")+s%60 }
                            color: "#7a6060"; font.pixelSize: 11; font.family: "JetBrainsMono Nerd Font Mono"
                        }
                    }
                }

                RowLayout {
                    Layout.alignment: Qt.AlignHCenter; spacing: 28
                    Repeater {
                        model: [
                            { svg: Qt.resolvedUrl("icons/previous-filled.svg") },
                            { svg: root.playerPlaying ? Qt.resolvedUrl("icons/pause-filled.svg") : Qt.resolvedUrl("icons/play-filled.svg") },
                            { svg: Qt.resolvedUrl("icons/next-filled.svg") }
                        ]
                        Item {
                            required property var modelData; required property int index
                            width: 28; height: 28
                            Image { id: ctrlImg; anchors.fill: parent; source: modelData.svg; smooth: true; mipmap: true }
                            MultiEffect {
                                source: ctrlImg; anchors.fill: ctrlImg
                                colorization: 1.0
                                colorizationColor: index === 1 ? root.cPrimary : root.cOnSurfaceVar
                            }
                            MouseArea {
                                anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    var p = root.currentPlayer; if (!p) return
                                    if (index === 0) p.previous()
                                    else if (index === 1) p.togglePlaying()
                                    else p.next()
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
