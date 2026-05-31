import Quickshell
import Quickshell.Wayland
import Quickshell.Bluetooth
import QtQuick
import QtQuick.Layouts
import "."
import QtQuick.Effects

PanelWindow {
    id: root


    readonly property var  adapter:    Bluetooth.defaultAdapter
    readonly property bool btEnabled:  adapter?.enabled ?? false
    readonly property var  friendlyDevices: {
        if (!adapter) return []
        var devs = Bluetooth.devices.values
        var connected = devs.filter(d => d.connected).sort((a,b) => a.name.localeCompare(b.name))
        var paired    = devs.filter(d => d.paired && !d.connected).sort((a,b) => a.name.localeCompare(b.name))
        var other     = devs.filter(d => !d.paired && !d.connected).sort((a,b) => a.name.localeCompare(b.name))
        return [...connected, ...paired, ...other]
    }

    property string expandedDevice: ""

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
    implicitWidth: 300
    implicitHeight: Math.min(520, 80 + Math.max(deviceList.contentHeight, 30) + 20)

    component Btn: Rectangle {
        property string label:  ""
        property color  accent: Config.cPrimary
        property bool   danger: false
        height: 24; implicitWidth: bTxt.implicitWidth + 16; radius: 6
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

    Rectangle {
        anchors.fill: parent; radius: 14
        color: Config.cSurface
        border.color: Qt.rgba(Config.cPrimary.r, Config.cPrimary.g, Config.cPrimary.b, 0.22); border.width: 1
        focus: true
        Keys.onEscapePressed: root.visible = false

        ColumnLayout {
            anchors { fill: parent; margins: 14 }
            spacing: 8

            RowLayout {
                Text { text: "Bluetooth"; font.family: "JetBrainsMono Nerd Font Mono"
                       font.pixelSize: 15; font.weight: Font.Bold; color: Config.cOnSurface }
                Item { Layout.fillWidth: true }
                Rectangle {
                    width: 44; height: 24; radius: 12
                    color: root.btEnabled ? Qt.rgba(Config.cPrimary.r, Config.cPrimary.g, Config.cPrimary.b, 0.25)
                                          : Qt.rgba(Config.cOnSurfaceVar.r, Config.cOnSurfaceVar.g, Config.cOnSurfaceVar.b, 0.18)
                    border.color: root.btEnabled ? Config.cPrimary : Config.cOnSurfaceVar; border.width: 1
                    Rectangle {
                        width: 16; height: 16; radius: 8; anchors.verticalCenter: parent.verticalCenter
                        x: root.btEnabled ? parent.width - 20 : 4
                        color: root.btEnabled ? Config.cPrimary : Config.cOnSurfaceVar
                        Behavior on x { NumberAnimation { duration: 150 } }
                    }
                    MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                        onClicked: { if (root.adapter) root.adapter.enabled = !root.btEnabled } }
                }
                Rectangle {
                    width: 28; height: 28; radius: 7; visible: root.btEnabled
                    color: sMa.containsMouse ? Qt.rgba(Config.cPrimary.r, Config.cPrimary.g, Config.cPrimary.b, 0.15) : "transparent"
                    Text { anchors.centerIn: parent; text: root.adapter?.discovering ? "…" : "↻"
                           font.pixelSize: 15; color: Config.cPrimary; font.family: "JetBrainsMono Nerd Font Mono" }
                    MouseArea { id: sMa; anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                        onClicked: { if (root.adapter) root.adapter.discovering = !root.adapter.discovering } }
                }
            }

            Rectangle { Layout.fillWidth: true; height: 1; color: Qt.rgba(Config.cPrimary.r, Config.cPrimary.g, Config.cPrimary.b, 0.12) }

            Text { visible: !root.btEnabled; Layout.alignment: Qt.AlignHCenter; text: "Bluetooth is off"
                   font.family: "JetBrainsMono Nerd Font Mono"; font.pixelSize: 13; color: Config.cOnSurfaceVar }

            ListView {
                id: deviceList
                Layout.fillWidth: true; Layout.fillHeight: true
                visible: root.btEnabled; clip: true; spacing: 2
                model: root.friendlyDevices

                delegate: Rectangle {
                    id: dItem
                    required property var modelData
                    property bool expanded: root.expandedDevice === modelData.name
                    width: deviceList.width
                    height: expanded ? 44 + actRow.implicitHeight + 14 : 44
                    radius: 8
                    color: modelData.connected
                           ? Qt.rgba(Config.cPrimary.r, Config.cPrimary.g, Config.cPrimary.b, 0.12)
                           : dMa.containsMouse && !expanded ? Qt.rgba(Config.cOnSurface.r, Config.cOnSurface.g, Config.cOnSurface.b, 0.06) : "transparent"
                    Behavior on height { NumberAnimation { duration: 150 } }
                    clip: true

                    MouseArea { id: dMa; anchors { top: parent.top; left: parent.left; right: parent.right }
                        height: 44; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                        onClicked: root.expandedDevice = expanded ? "" : modelData.name }

                    ColumnLayout {
                        anchors { fill: parent; margins: 10 }
                        spacing: 6

                        RowLayout {
                            spacing: 10
                            Item {
                                width: 20; height: 20
                                Image { id: dImg; anchors.fill: parent; smooth: true; mipmap: true
                                    source: {
                                        var ic = dItem.modelData.icon || ""
                                        if (ic.includes("headphone") || ic.includes("headset") || ic.includes("audio"))
                                            return Qt.resolvedUrl("icons/headphones-filled.svg")
                                        if (ic.includes("phone")) return Qt.resolvedUrl("icons/phone-filled.svg")
                                        return Qt.resolvedUrl("icons/bluetooth-filled.svg")
                                    }
                                }
                                MultiEffect { source: dImg; anchors.fill: dImg; colorization: 1.0
                                    colorizationColor: modelData.connected ? Config.cPrimary : Config.cOnSurfaceVar }
                            }
                            ColumnLayout { Layout.fillWidth: true; spacing: 1
                                Text { Layout.fillWidth: true; elide: Text.ElideRight
                                       text: modelData.name || "Unknown"
                                       font.family: "JetBrainsMono Nerd Font Mono"; font.pixelSize: 13
                                       font.weight: modelData.connected ? Font.Medium : Font.Normal
                                       color: modelData.connected ? Config.cPrimary : Config.cOnSurface }
                                Text { visible: modelData.connected || modelData.paired
                                       text: {
                                           var s = modelData.connected ? "Connected" : "Paired"
                                           if (modelData.trusted) s += " · trusted"
                                           if (modelData.connected && modelData.batteryAvailable)
                                               s += "  " + Math.round(modelData.battery * 100) + "%"
                                           return s
                                       }
                                       font.family: "JetBrainsMono Nerd Font Mono"; font.pixelSize: 10; color: Config.cOnSurfaceVar }
                            }
                            Text { text: expanded ? "▲" : "▼"; font.pixelSize: 10; color: Config.cOnSurfaceVar }
                        }

                        // Action buttons
                        RowLayout {
                            id: actRow
                            visible: expanded; spacing: 5

                            Btn {
                                label: modelData.connected ? "Disconnect" : "Connect"
                                onClicked: {
                                    if (modelData.connected) modelData.disconnect()
                                    else { modelData.trusted = true; modelData.connect() }
                                    root.expandedDevice = ""
                                }
                            }
                            Btn {
                                label: modelData.trusted ? "Untrust" : "Trust"
                                onClicked: modelData.trusted = !modelData.trusted
                            }
                            Item { Layout.fillWidth: true }
                            Btn {
                                label: "Forget"; danger: true; accent: Config.cError
                                onClicked: { modelData.forget(); root.expandedDevice = "" }
                            }
                        }
                    }
                }
            }

            Text {
                visible: root.btEnabled && root.friendlyDevices.length === 0
                text: root.adapter?.discovering ? "Scanning…" : "No devices\nPress ↻ to scan"
                font.family: "JetBrainsMono Nerd Font Mono"; font.pixelSize: 12; color: Config.cOnSurfaceVar
                horizontalAlignment: Text.AlignHCenter; Layout.alignment: Qt.AlignHCenter
            }
        }
    }
}
