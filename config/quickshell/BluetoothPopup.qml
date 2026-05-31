import Quickshell
import Quickshell.Wayland
import Quickshell.Bluetooth
import QtQuick
import QtQuick.Layouts
import QtQuick.Effects

PanelWindow {
    id: root

    property color cSurface:      "#131318"
    property color cPrimary:      "#ffb3b4"
    property color cOnSurface:    "#f0dede"
    property color cOnSurfaceVar: "#d8bfbf"
    property color cError:        "#ffb4ab"

    readonly property var adapter:    Bluetooth.defaultAdapter
    readonly property bool btEnabled: adapter?.enabled ?? false
    readonly property var friendlyDevices: {
        if (!adapter) return []
        var devs = Bluetooth.devices.values
        var connected = devs.filter(d => d.connected).sort((a,b) => a.name.localeCompare(b.name))
        var paired    = devs.filter(d => d.paired && !d.connected).sort((a,b) => a.name.localeCompare(b.name))
        var other     = devs.filter(d => !d.paired && !d.connected).sort((a,b) => a.name.localeCompare(b.name))
        return [...connected, ...paired, ...other]
    }

    anchors { top: true; right: true }
    margins { top: 48; right: 12 }
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
    exclusionMode: ExclusionMode.Ignore
    color: "transparent"
    implicitWidth: 300
    implicitHeight: Math.min(480, 80 + Math.max(deviceList.contentHeight, 30) + 20)

    Rectangle {
        anchors.fill: parent; radius: 14
        color: root.cSurface
        border.color: Qt.rgba(root.cPrimary.r, root.cPrimary.g, root.cPrimary.b, 0.22)
        border.width: 1

        ColumnLayout {
            anchors { fill: parent; margins: 14 }
            spacing: 8

            RowLayout {
                Text {
                    text: "Bluetooth"; font.family: "JetBrainsMono Nerd Font Mono"
                    font.pixelSize: 15; font.weight: Font.Bold; color: root.cOnSurface
                }
                Item { Layout.fillWidth: true }

                // Power toggle
                Rectangle {
                    width: 44; height: 24; radius: 12
                    color: root.btEnabled ? Qt.rgba(root.cPrimary.r, root.cPrimary.g, root.cPrimary.b, 0.25) : Qt.rgba(root.cOnSurfaceVar.r, root.cOnSurfaceVar.g, root.cOnSurfaceVar.b, 0.18)
                    border.color: root.btEnabled ? root.cPrimary : root.cOnSurfaceVar; border.width: 1
                    Rectangle {
                        width: 16; height: 16; radius: 8
                        anchors.verticalCenter: parent.verticalCenter
                        x: root.btEnabled ? parent.width - 20 : 4
                        color: root.btEnabled ? root.cPrimary : root.cOnSurfaceVar
                        Behavior on x { NumberAnimation { duration: 150 } }
                    }
                    MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                        onClicked: { if (root.adapter) root.adapter.enabled = !root.btEnabled } }
                }

                // Scan
                Rectangle {
                    width: 28; height: 28; radius: 7; visible: root.btEnabled
                    color: sMa.containsMouse ? Qt.rgba(root.cPrimary.r, root.cPrimary.g, root.cPrimary.b, 0.15) : "transparent"
                    Text { anchors.centerIn: parent; text: root.adapter?.discovering ? "…" : "↻"; font.pixelSize: 15; color: root.cPrimary; font.family: "JetBrainsMono Nerd Font Mono" }
                    MouseArea { id: sMa; anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                        onClicked: { if (root.adapter) root.adapter.discovering = !root.adapter.discovering } }
                }
            }

            Rectangle { Layout.fillWidth: true; height: 1; color: Qt.rgba(root.cPrimary.r, root.cPrimary.g, root.cPrimary.b, 0.12) }

            Text {
                visible: !root.btEnabled
                text: "Bluetooth is off"; Layout.alignment: Qt.AlignHCenter
                font.family: "JetBrainsMono Nerd Font Mono"; font.pixelSize: 13; color: root.cOnSurfaceVar
            }

            ListView {
                id: deviceList
                Layout.fillWidth: true; Layout.fillHeight: true
                visible: root.btEnabled; clip: true; spacing: 2
                model: root.friendlyDevices

                delegate: Rectangle {
                    id: dItem
                    required property var modelData
                    width: deviceList.width; height: 44; radius: 8
                    color: modelData.connected
                           ? Qt.rgba(root.cPrimary.r, root.cPrimary.g, root.cPrimary.b, 0.12)
                           : dMa.containsMouse ? Qt.rgba(root.cOnSurface.r, root.cOnSurface.g, root.cOnSurface.b, 0.06) : "transparent"

                    MouseArea { id: dMa; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                        onClicked: { if (modelData.connected) modelData.disconnect(); else modelData.connect() } }

                    RowLayout {
                        anchors { fill: parent; margins: 10 }
                        spacing: 10

                        Item {
                            width: 20; height: 20
                            Image {
                                id: dImg; anchors.fill: parent; smooth: true; mipmap: true
                                source: {
                                    var ic = dItem.modelData.icon || ""
                                    if (ic.includes("headphone") || ic.includes("headset") || ic.includes("audio"))
                                        return Qt.resolvedUrl("icons/headphones-filled.svg")
                                    if (ic.includes("phone"))
                                        return Qt.resolvedUrl("icons/phone-filled.svg")
                                    return Qt.resolvedUrl("icons/bluetooth-filled.svg")
                                }
                            }
                            MultiEffect { source: dImg; anchors.fill: dImg; colorization: 1.0
                                colorizationColor: modelData.connected ? root.cPrimary : root.cOnSurfaceVar }
                        }

                        ColumnLayout { Layout.fillWidth: true; spacing: 1
                            Text {
                                Layout.fillWidth: true; elide: Text.ElideRight
                                text: modelData.name || "Unknown"
                                font.family: "JetBrainsMono Nerd Font Mono"; font.pixelSize: 13
                                font.weight: modelData.connected ? Font.Medium : Font.Normal
                                color: modelData.connected ? root.cPrimary : root.cOnSurface
                            }
                            Text {
                                visible: modelData.connected || modelData.paired
                                text: {
                                    var s = modelData.connected ? "Connected" : "Paired"
                                    if (modelData.connected && modelData.batteryAvailable)
                                        s += "  " + Math.round(modelData.battery * 100) + "%"
                                    return s
                                }
                                font.family: "JetBrainsMono Nerd Font Mono"; font.pixelSize: 10; color: root.cOnSurfaceVar
                            }
                        }

                        Text { text: modelData.connected ? "✓" : ""; font.pixelSize: 13; color: root.cPrimary }
                    }
                }
            }

            Text {
                visible: root.btEnabled && root.friendlyDevices.length === 0
                text: root.adapter?.discovering ? "Scanning…" : "No devices\nPress ↻ to scan"
                font.family: "JetBrainsMono Nerd Font Mono"; font.pixelSize: 12; color: root.cOnSurfaceVar
                horizontalAlignment: Text.AlignHCenter; Layout.alignment: Qt.AlignHCenter
            }
        }
    }
}
