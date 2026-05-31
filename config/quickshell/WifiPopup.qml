import Quickshell
import Quickshell.Wayland
import Quickshell.Io
import QtQuick
import QtQuick.Layouts

PanelWindow {
    id: root

    property color cSurface:       "#131318"
    property color cPrimary:       "#ffb3b4"
    property color cOnSurface:     "#f0dede"
    property color cOnSurfaceVar:  "#d8bfbf"
    property color cError:         "#ffb4ab"

    property bool   scanning:    false
    property string connecting:  ""
    property string askPassFor:  ""
    property string statusText:  ""
    property var    networks:    []

    anchors { top: true; right: true }
    margins { top: 48; right: 12 }
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.OnDemand
    exclusionMode: ExclusionMode.Ignore
    color: "transparent"
    implicitWidth: 320
    implicitHeight: Math.min(520, headerCol.implicitHeight + networkList.contentHeight + 32)

    // ── nmcli processes ───────────────────────────────────────────
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
        id: connectProc
        environment: ({ LANG: "C", LC_ALL: "C" })
        stderr: SplitParser {
            onRead: data => {
                if (data.includes("Secrets were required") || data.toLowerCase().includes("password"))
                    root.askPassFor = root.connecting
            }
        }
        onExited: (code) => {
            if (code === 0) {
                root.statusText = "Connected ✓"
                root.connecting = ""; root.askPassFor = ""
                Qt.callLater(() => scanProc.running = true)
            } else if (!root.askPassFor) {
                root.statusText = "Failed"
                root.connecting = ""
            }
        }
    }

    Process {
        id: disconnectProc
        onExited: Qt.callLater(() => scanProc.running = true)
    }

    Process {
        id: monitorProc; running: true
        command: ["nmcli", "monitor"]
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

    // ── UI ────────────────────────────────────────────────────────
    Rectangle {
        anchors.fill: parent; radius: 14
        color: root.cSurface
        border.color: Qt.rgba(root.cPrimary.r, root.cPrimary.g, root.cPrimary.b, 0.22)
        border.width: 1

        ColumnLayout {
            anchors { fill: parent; margins: 14 }
            spacing: 8

            ColumnLayout {
                id: headerCol
                spacing: 4

                RowLayout {
                    Text {
                        text: "Wi-Fi"; font.family: "JetBrainsMono Nerd Font Mono"
                        font.pixelSize: 15; font.weight: Font.Bold; color: root.cOnSurface
                    }
                    Item { Layout.fillWidth: true }
                    Rectangle {
                        width: 28; height: 28; radius: 7
                        color: rMa.containsMouse ? Qt.rgba(root.cPrimary.r, root.cPrimary.g, root.cPrimary.b, 0.15) : "transparent"
                        Text { anchors.centerIn: parent; text: root.scanning ? "…" : "↻"; font.pixelSize: 15; color: root.cPrimary; font.family: "JetBrainsMono Nerd Font Mono" }
                        MouseArea { id: rMa; anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                            onClicked: { root.scanning = true; scanProc.running = true } }
                    }
                }

                Text {
                    visible: root.statusText !== ""
                    text: root.statusText; font.family: "JetBrainsMono Nerd Font Mono"; font.pixelSize: 12
                    color: root.statusText.includes("✓") ? "#a6e3a1"
                         : root.statusText === "Failed"  ? root.cError : root.cOnSurfaceVar
                }
            }

            // Separator
            Rectangle { Layout.fillWidth: true; height: 1; color: Qt.rgba(root.cPrimary.r, root.cPrimary.g, root.cPrimary.b, 0.12) }

            ListView {
                id: networkList
                Layout.fillWidth: true
                Layout.fillHeight: true
                clip: true; spacing: 2

                model: root.networks
                delegate: Rectangle {
                    id: nd
                    required property var modelData
                    width: networkList.width
                    height: modelData.ssid === root.askPassFor ? passLayout.implicitHeight + 20 : 38
                    radius: 8
                    color: modelData.active
                           ? Qt.rgba(root.cPrimary.r, root.cPrimary.g, root.cPrimary.b, 0.12)
                           : hma.containsMouse ? Qt.rgba(root.cOnSurface.r, root.cOnSurface.g, root.cOnSurface.b, 0.06) : "transparent"
                    Behavior on height { NumberAnimation { duration: 150 } }

                    MouseArea {
                        id: hma; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            if (modelData.active) { root.disconnect(modelData.ssid) }
                            else if (root.askPassFor !== modelData.ssid) { root.connectTo(modelData.ssid) }
                        }
                    }

                    ColumnLayout {
                        id: passLayout
                        anchors { fill: parent; margins: 8 }
                        spacing: 6

                        // Network row
                        RowLayout {
                            spacing: 8
                            // Signal bars
                            Item {
                                width: 16; height: 14
                                Layout.alignment: Qt.AlignVCenter
                                Repeater {
                                    model: 4
                                    Rectangle {
                                        required property int index
                                        width: 3; radius: 1
                                        height: 4 + index * 3
                                        x: index * 4
                                        y: parent.height - height
                                        color: (nd.modelData.signal / 25) > index
                                               ? (nd.modelData.active ? root.cPrimary : root.cOnSurfaceVar)
                                               : Qt.rgba(root.cOnSurfaceVar.r, root.cOnSurfaceVar.g, root.cOnSurfaceVar.b, 0.25)
                                    }
                                }
                            }

                            Text {
                                Layout.fillWidth: true
                                text: modelData.ssid; elide: Text.ElideRight
                                font.family: "JetBrainsMono Nerd Font Mono"; font.pixelSize: 13
                                font.weight: modelData.active ? Font.Medium : Font.Normal
                                color: modelData.active ? root.cPrimary : root.cOnSurface
                            }

                            Text {
                                text: root.connecting === modelData.ssid ? "…"
                                    : modelData.active ? "✓"
                                    : modelData.secure ? "🔒" : ""
                                font.pixelSize: 12
                                color: modelData.active ? root.cPrimary : root.cOnSurfaceVar
                            }
                        }

                        // Password prompt
                        ColumnLayout {
                            visible: root.askPassFor === modelData.ssid
                            spacing: 6

                            Rectangle {
                                Layout.fillWidth: true; height: 32; radius: 6
                                color: Qt.rgba(root.cOnSurface.r, root.cOnSurface.g, root.cOnSurface.b, 0.08)
                                border.color: Qt.rgba(root.cPrimary.r, root.cPrimary.g, root.cPrimary.b, pf.activeFocus ? 0.50 : 0.20)
                                border.width: 1
                                TextInput {
                                    id: pf
                                    anchors { fill: parent; margins: 8 }
                                    font.family: "JetBrainsMono Nerd Font Mono"; font.pixelSize: 12
                                    color: root.cOnSurface; echoMode: TextInput.Password
                                    Keys.onReturnPressed: root.connectWithPass(nd.modelData.ssid, pf.text)
                                    Keys.onEscapePressed: { root.askPassFor = ""; pf.text = "" }
                                    Component.onCompleted: if (visible) forceActiveFocus()
                                }
                            }

                            RowLayout {
                                Item { Layout.fillWidth: true }
                                Repeater {
                                    model: [{ t: "Cancel", action: "cancel" }, { t: "Connect", action: "connect" }]
                                    Rectangle {
                                        required property var modelData
                                        width: 70; height: 26; radius: 6
                                        color: bma.containsMouse
                                               ? Qt.rgba(root.cPrimary.r, root.cPrimary.g, root.cPrimary.b, modelData.action==="connect" ? 0.25 : 0.08)
                                               : Qt.rgba(root.cPrimary.r, root.cPrimary.g, root.cPrimary.b, modelData.action==="connect" ? 0.12 : 0)
                                        border.color: Qt.rgba(root.cPrimary.r, root.cPrimary.g, root.cPrimary.b, modelData.action==="connect" ? 0.35 : 0)
                                        border.width: 1
                                        Text { anchors.centerIn: parent; text: modelData.t; font.pixelSize: 12; color: root.cPrimary; font.family: "JetBrainsMono Nerd Font Mono" }
                                        MouseArea {
                                            id: bma; anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                                            onClicked: {
                                                if (modelData.action === "connect") root.connectWithPass(nd.modelData.ssid, pf.text)
                                                else { root.askPassFor = ""; pf.text = "" }
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
