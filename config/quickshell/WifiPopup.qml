import Quickshell
import Quickshell.Wayland
import Quickshell.Io
import QtQuick
import QtQuick.Layouts
import "."

PanelWindow {
    id: root


    property bool   scanning:     false
    property bool   wifiEnabled:  true
    property string connecting:   ""
    property string askPassFor:   ""
    property string statusText:   ""
    property string expandedSsid: ""
    property var    networks:     []

    anchors.top:    Config.barPosition === "top"
    anchors.bottom: Config.barPosition !== "top"
    anchors.left:   Config.barPosition === "left"
    anchors.right:  Config.barPosition !== "left"
    margins {
        top:    Config.barPosition === "top"    ? Config.barThickness + 4 : 0
        bottom: Config.barPosition === "bottom" ? Config.barThickness + 4 : (Config.barPosition !== "top" ? 8 : 0)
        left:   Config.barPosition === "left"   ? Config.barThickness + 8 : 0
        right:  Config.barPosition !== "left"   ? 8 : 0
    }
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.OnDemand
    exclusionMode: ExclusionMode.Ignore
    color: "transparent"
    implicitWidth: 320
    implicitHeight: Math.min(540, headerCol.implicitHeight + networkList.contentHeight + 40)

    component Btn: Rectangle {
        property string label:  ""
        property color  accent: Config.cPrimary
        property bool   danger: false
        height: 24; implicitWidth: bTxt.implicitWidth + 14; radius: 6
        color: bMa.containsMouse
               ? Qt.rgba(accent.r, accent.g, accent.b, danger ? 0.25 : 0.20)
               : Qt.rgba(accent.r, accent.g, accent.b, danger ? 0.15 : 0.10)
        border.color: Qt.rgba(accent.r, accent.g, accent.b, 0.35); border.width: 1
        Text { id: bTxt; anchors.centerIn: parent; text: label
               font.family: "JetBrainsMono Nerd Font Mono"; font.pixelSize: 11
               color: danger ? Config.cError : Config.cPrimary }
        MouseArea { id: bMa; anchors.fill: parent; cursorShape: Qt.PointingHandCursor }
        signal clicked()
        Component.onCompleted: bMa.clicked.connect(clicked)
    }

    Process {
        id: scanProc
        command: ["nmcli", "-g", "ACTIVE,SIGNAL,SSID,SECURITY", "d", "w"]
        environment: ({ LANG: "C", LC_ALL: "C" })
        stdout: StdioCollector {
            onStreamFinished: {
                root.scanning = false
                var map = {}
                text.trim().split("\n").forEach(line => {
                    if (!line) return
                    var p = line.replace(/\\:/g, "\x00").split(":")
                    if (p.length < 3) return
                    var active = p[0] === "yes"
                    var signal = parseInt(p[1]) || 0
                    var ssid   = p[2].replace(/\x00/g, ":")
                    var sec    = (p[3] || "").replace(/\x00/g, ":").trim()
                    if (!ssid) return
                    if (!map[ssid] || active || signal > (map[ssid].signal || 0))
                        map[ssid] = { active, signal, ssid, secure: sec.length > 0 && sec !== "--" }
                })
                root.networks = Object.values(map).sort((a, b) => {
                    if (a.active !== b.active) return a.active ? -1 : 1
                    return b.signal - a.signal
                })
            }
        }
    }

    Process {
        id: connectProc; environment: ({ LANG: "C", LC_ALL: "C" })
        stderr: SplitParser {
            onRead: data => {
                if (data.includes("Secrets were required") || data.toLowerCase().includes("password"))
                    root.askPassFor = root.connecting
            }
        }
        onExited: (code) => {
            if (code === 0) {
                root.statusText = "Connected ✓"; root.connecting = ""; root.askPassFor = ""
                Qt.callLater(() => scanProc.running = true)
            } else if (!root.askPassFor) {
                root.statusText = "Failed"; root.connecting = ""
            }
        }
    }

    Process { id: disconnectProc; onExited: Qt.callLater(() => scanProc.running = true) }
    Process { id: forgetProc;     onExited: Qt.callLater(() => scanProc.running = true) }
    Process {
        id: powerProc
        onExited: Qt.callLater(() => { wifiStatusProc.running = true; scanProc.running = true })
    }
    Process {
        id: wifiStatusProc; running: true
        command: ["nmcli", "radio", "wifi"]
        environment: ({ LANG: "C", LC_ALL: "C" })
        stdout: SplitParser { onRead: data => root.wifiEnabled = data.trim() === "enabled" }
    }
    Process {
        id: monitorProc; running: true; command: ["nmcli", "monitor"]
        stdout: SplitParser { onRead: _ => Qt.callLater(() => { if (!scanProc.running) scanProc.running = true }) }
    }

    Component.onCompleted: { scanning = true; scanProc.running = true }

    function connectTo(ssid) {
        connecting = ssid; askPassFor = ""; statusText = "Connecting…"
        connectProc.command = ["nmcli", "dev", "wifi", "connect", ssid]
        connectProc.running = true
    }
    function connectWithPass(ssid, pass) {
        connecting = ssid; askPassFor = ""; statusText = "Connecting…"
        connectProc.command = ["nmcli", "dev", "wifi", "connect", ssid, "password", pass]
        connectProc.running = true
    }
    function disconnect(ssid) {
        statusText = "Disconnecting…"
        disconnectProc.command = ["nmcli", "connection", "down", ssid]
        disconnectProc.running = true
    }
    function forget(ssid) {
        statusText = "Forgotten"
        forgetProc.command = ["nmcli", "connection", "delete", ssid]
        forgetProc.running = true
    }
    function toggleWifi() {
        powerProc.command = ["nmcli", "radio", "wifi", root.wifiEnabled ? "off" : "on"]
        powerProc.running = true
    }

    Rectangle {
        anchors.fill: parent; radius: 14
        color: Config.cSurface
        border.color: Qt.rgba(Config.cPrimary.r, Config.cPrimary.g, Config.cPrimary.b, 0.22); border.width: 1
        focus: true
        Keys.onEscapePressed: root.visible = false

        ColumnLayout {
            anchors { fill: parent; margins: 14 }
            spacing: 8

            ColumnLayout {
                id: headerCol; spacing: 4
                RowLayout {
                    Text { text: "Wi-Fi"; font.family: "JetBrainsMono Nerd Font Mono"
                           font.pixelSize: 15; font.weight: Font.Bold; color: Config.cOnSurface }
                    Item { Layout.fillWidth: true }
                    // Power toggle
                    Rectangle {
                        width: 44; height: 24; radius: 12
                        color: root.wifiEnabled ? Qt.rgba(Config.cPrimary.r, Config.cPrimary.g, Config.cPrimary.b, 0.25)
                                                : Qt.rgba(Config.cOnSurfaceVar.r, Config.cOnSurfaceVar.g, Config.cOnSurfaceVar.b, 0.18)
                        border.color: root.wifiEnabled ? Config.cPrimary : Config.cOnSurfaceVar; border.width: 1
                        Rectangle {
                            width: 16; height: 16; radius: 8; anchors.verticalCenter: parent.verticalCenter
                            x: root.wifiEnabled ? parent.width - 20 : 4
                            color: root.wifiEnabled ? Config.cPrimary : Config.cOnSurfaceVar
                            Behavior on x { NumberAnimation { duration: 150 } }
                        }
                        MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: root.toggleWifi() }
                    }
                    // Rescan
                    Rectangle {
                        width: 28; height: 28; radius: 7; visible: root.wifiEnabled
                        color: rMa.containsMouse ? Qt.rgba(Config.cPrimary.r, Config.cPrimary.g, Config.cPrimary.b, 0.15) : "transparent"
                        Text { anchors.centerIn: parent; text: root.scanning ? "…" : "↻"
                               font.pixelSize: 15; color: Config.cPrimary; font.family: "JetBrainsMono Nerd Font Mono" }
                        MouseArea { id: rMa; anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                            onClicked: { root.scanning = true; scanProc.running = true } }
                    }
                }
                Text { visible: root.statusText !== ""; text: root.statusText
                       font.family: "JetBrainsMono Nerd Font Mono"; font.pixelSize: 12
                       color: root.statusText.includes("✓") ? "#a6e3a1"
                            : root.statusText === "Failed"  ? Config.cError : Config.cOnSurfaceVar }
            }

            Rectangle { Layout.fillWidth: true; height: 1; color: Qt.rgba(Config.cPrimary.r, Config.cPrimary.g, Config.cPrimary.b, 0.12) }

            Text { visible: !root.wifiEnabled; Layout.alignment: Qt.AlignHCenter; text: "Wi-Fi is off"
                   font.family: "JetBrainsMono Nerd Font Mono"; font.pixelSize: 13; color: Config.cOnSurfaceVar }

            ListView {
                id: networkList
                Layout.fillWidth: true; Layout.fillHeight: true
                visible: root.wifiEnabled; clip: true; spacing: 2
                model: root.networks

                delegate: Rectangle {
                    id: nd
                    required property var modelData
                    property bool expanded: root.expandedSsid === modelData.ssid && modelData.ssid !== root.askPassFor
                    width: networkList.width
                    height: modelData.ssid === root.askPassFor ? passLayout.implicitHeight + 20
                          : expanded ? 38 + actRow.implicitHeight + 10 : 38
                    radius: 8
                    color: modelData.active
                           ? Qt.rgba(Config.cPrimary.r, Config.cPrimary.g, Config.cPrimary.b, 0.12)
                           : hma.containsMouse && !expanded ? Qt.rgba(Config.cOnSurface.r, Config.cOnSurface.g, Config.cOnSurface.b, 0.06) : "transparent"
                    Behavior on height { NumberAnimation { duration: 150 } }
                    clip: true

                    MouseArea {
                        id: hma; anchors { top: parent.top; left: parent.left; right: parent.right }
                        height: 38; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            if (modelData.ssid === root.askPassFor) return
                            root.expandedSsid = expanded ? "" : modelData.ssid
                        }
                    }

                    ColumnLayout {
                        id: passLayout
                        anchors { fill: parent; margins: 8 }
                        spacing: 6

                        RowLayout {
                            spacing: 8
                            Item {
                                width: 16; height: 14; Layout.alignment: Qt.AlignVCenter
                                Repeater {
                                    model: 4
                                    Rectangle {
                                        required property int index
                                        width: 3; radius: 1; height: 4 + index * 3
                                        x: index * 4; y: parent.height - height
                                        color: (nd.modelData.signal / 25) > index
                                               ? (nd.modelData.active ? Config.cPrimary : Config.cOnSurfaceVar)
                                               : Qt.rgba(Config.cOnSurfaceVar.r, Config.cOnSurfaceVar.g, Config.cOnSurfaceVar.b, 0.25)
                                    }
                                }
                            }
                            Text {
                                Layout.fillWidth: true; text: modelData.ssid; elide: Text.ElideRight
                                font.family: "JetBrainsMono Nerd Font Mono"; font.pixelSize: 13
                                font.weight: modelData.active ? Font.Medium : Font.Normal
                                color: modelData.active ? Config.cPrimary : Config.cOnSurface
                            }
                            Text {
                                text: root.connecting === modelData.ssid ? "…"
                                    : modelData.active ? "✓" : modelData.secure ? "🔒" : ""
                                font.pixelSize: 12; color: modelData.active ? Config.cPrimary : Config.cOnSurfaceVar
                            }
                        }

                        // Action buttons
                        RowLayout {
                            id: actRow; visible: expanded; spacing: 5
                            Btn {
                                label: modelData.active ? "Disconnect" : "Connect"
                                onClicked: {
                                    root.expandedSsid = ""
                                    if (modelData.active) root.disconnect(modelData.ssid)
                                    else root.connectTo(modelData.ssid)
                                }
                            }
                            Item { Layout.fillWidth: true }
                            Btn {
                                label: "Forget"; danger: true; accent: Config.cError
                                onClicked: { root.expandedSsid = ""; root.forget(modelData.ssid) }
                            }
                        }

                        // Password prompt
                        ColumnLayout {
                            visible: root.askPassFor === modelData.ssid; spacing: 6
                            Rectangle {
                                Layout.fillWidth: true; height: 32; radius: 6
                                color: Qt.rgba(Config.cOnSurface.r, Config.cOnSurface.g, Config.cOnSurface.b, 0.08)
                                border.color: Qt.rgba(Config.cPrimary.r, Config.cPrimary.g, Config.cPrimary.b, pf.activeFocus ? 0.50 : 0.20); border.width: 1
                                TextInput {
                                    id: pf; anchors { fill: parent; margins: 8 }
                                    font.family: "JetBrainsMono Nerd Font Mono"; font.pixelSize: 12
                                    color: Config.cOnSurface; echoMode: TextInput.Password
                                    Keys.onReturnPressed: root.connectWithPass(nd.modelData.ssid, pf.text)
                                    Keys.onEscapePressed: { root.askPassFor = ""; pf.text = "" }
                                    Component.onCompleted: if (visible) forceActiveFocus()
                                }
                            }
                            RowLayout {
                                Item { Layout.fillWidth: true }
                                Btn { label: "Cancel"; onClicked: { root.askPassFor = ""; pf.text = "" } }
                                Btn { label: "Connect"; onClicked: root.connectWithPass(nd.modelData.ssid, pf.text) }
                            }
                        }
                    }
                }
            }
        }
    }
}
