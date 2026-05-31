import Quickshell
import "."
import Quickshell.Wayland
import Quickshell.Hyprland
import Quickshell.Services.Pipewire
import Quickshell.Bluetooth
import QtQuick
import QtQuick.Layouts
import QtQuick.Effects

// Absolute positioning: workspaces top, clock centered, icons bottom — clock never moves
Item {
    // ── Workspaces (pinned top) ───────────────────────────────────
    ColumnLayout {
        anchors { top: parent.top; topMargin: 8; horizontalCenter: parent.horizontalCenter }
        spacing: 8
        Repeater {
            model: {
                var ids = [1, 2, 3, 4, 5]
                for (var i = 0; i < Hyprland.workspaces.values.length; i++) {
                    var id = Hyprland.workspaces.values[i].id
                    if (id > 5 && ids.indexOf(id) < 0) ids.push(id)
                }
                ids.sort((a,b) => a - b); return ids
            }
            delegate: Item {
                id: vWsDel
                required property int modelData
                property var ws: {
                    for (var i = 0; i < Hyprland.workspaces.values.length; i++)
                        if (Hyprland.workspaces.values[i].id === modelData) return Hyprland.workspaces.values[i]
                    return null
                }
                property bool focused:  ws ? ws.focused : false
                property bool occupied: ws ? ws.clientCount > 0 : false
                property string activeAppId: occupied ? (Config.wsApps[modelData] || (focused ? (ToplevelManager.activeToplevel?.appId ?? "") : "")) : ""
                Layout.alignment: Qt.AlignHCenter
                implicitWidth:  focused ? 32 : occupied ? 26 : 22
                implicitHeight: implicitWidth
                Rectangle {
                    anchors.fill: parent; radius: 6
                    color: vWsDel.focused ? Qt.rgba(Config.cPrimary.r, Config.cPrimary.g, Config.cPrimary.b, 0.18)
                         : vWsDel.occupied ? Qt.rgba(Config.cPrimary.r, Config.cPrimary.g, Config.cPrimary.b, 0.07) : "transparent"
                    border.color: Qt.rgba(Config.cPrimary.r, Config.cPrimary.g, Config.cPrimary.b, vWsDel.focused ? 0.50 : 0.16); border.width: 1
                    Image {
                        anchors.centerIn: parent; width: 16; height: 16; visible: vWsDel.focused && vWsDel.activeAppId !== ""
                        source: vWsDel.activeAppId ? "image://icon/" + vWsDel.activeAppId : ""; smooth: true; mipmap: true; fillMode: Image.PreserveAspectFit
                    }
                    Text {
                        anchors.centerIn: parent; visible: !vWsDel.focused || vWsDel.activeAppId === ""; text: modelData
                        font.family: "JetBrainsMono Nerd Font Mono"; font.pixelSize: 17; font.bold: vWsDel.focused
                        color: vWsDel.focused ? Config.cPrimary : vWsDel.occupied ? Config.cOnSurfaceVar : Qt.rgba(Config.cOnSurfaceVar.r, Config.cOnSurfaceVar.g, Config.cOnSurfaceVar.b, 0.45)
                    }
                    Rectangle {
                        anchors { right: parent.right; verticalCenter: parent.verticalCenter; rightMargin: 2 }
                        visible: vWsDel.occupied && !vWsDel.focused; width: 3; height: 3; radius: 2; color: Config.cOnSurfaceVar; opacity: 0.6
                    }
                }
                MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: Hyprland.dispatch("workspace " + modelData) }
                Behavior on implicitWidth  { NumberAnimation { duration: 150 } }
                Behavior on implicitHeight { NumberAnimation { duration: 150 } }
            }
        }
    }

    // ── Clock (absolutely centered — never shifts) ────────────────
    ColumnLayout {
        anchors.centerIn: parent; spacing: -2
        Text {
            Layout.alignment: Qt.AlignHCenter
            font.family: "JetBrainsMono Nerd Font Mono"; font.pixelSize: 19; font.weight: Font.Bold; color: Config.cOnSurface
            Timer { interval: 1000; running: parent.visible; repeat: true; onTriggered: parent.text = Qt.formatDateTime(new Date(), "HH") }
            Component.onCompleted: text = Qt.formatDateTime(new Date(), "HH")
        }
        Text {
            Layout.alignment: Qt.AlignHCenter
            font.family: "JetBrainsMono Nerd Font Mono"; font.pixelSize: 19; font.weight: Font.Bold
            color: Qt.rgba(Config.cOnSurface.r, Config.cOnSurface.g, Config.cOnSurface.b, 0.55)
            Timer { interval: 1000; running: parent.visible; repeat: true; onTriggered: parent.text = Qt.formatDateTime(new Date(), "mm") }
            Component.onCompleted: text = Qt.formatDateTime(new Date(), "mm")
        }
    }

    // ── Status icons (pinned bottom) ──────────────────────────────
    ColumnLayout {
        anchors { bottom: parent.bottom; bottomMargin: 8; horizontalCenter: parent.horizontalCenter }
        spacing: 8

        Item {
            Layout.alignment: Qt.AlignHCenter; width: 24; height: 24
            property var  sink:  Pipewire.defaultAudioSink
            property real vol:   sink && sink.audio ? Math.min(sink.audio.volume, 1.5) : 0
            property bool muted: sink && sink.audio ? sink.audio.muted : false
            Image { id: vVolImg; anchors.centerIn: parent; width: 18; height: 18; smooth: true; mipmap: true; fillMode: Image.PreserveAspectFit
                source: parent.muted ? Qt.resolvedUrl("icons/speaker-mute-filled.svg")
                      : parent.vol > 0.5 ? Qt.resolvedUrl("icons/speaker-2-filled.svg")
                      : parent.vol > 0.0 ? Qt.resolvedUrl("icons/speaker-1.svg") : Qt.resolvedUrl("icons/speaker-0.svg") }
            MultiEffect { source: vVolImg; anchors.fill: vVolImg; colorization: 1.0; colorizationColor: Config.cTertiary }
            MouseArea {
                anchors.fill: parent; hoverEnabled: true; acceptedButtons: Qt.MiddleButton
                onEntered: Config.vVolHovered = true; onExited: Config.vVolHovered = false
                onClicked: { var s = Pipewire.defaultAudioSink; if (s && s.audio) s.audio.muted = !s.audio.muted }
            }
            WheelHandler {
                acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
                onWheel: ev => {
                    var s = Pipewire.defaultAudioSink
                    if (s && s.audio) { s.audio.volume = Math.max(0, Math.min(1.5, s.audio.volume + (ev.angleDelta.y > 0 ? 0.05 : -0.05))); Config.osdRequested("volume") }
                }
            }
        }

        Item {
            Layout.alignment: Qt.AlignHCenter; width: 24; height: 24
            Image { id: vBriImg; anchors.centerIn: parent; width: 18; height: 18; smooth: true; mipmap: true; fillMode: Image.PreserveAspectFit; source: Qt.resolvedUrl("icons/weather-sunny-filled.svg") }
            MultiEffect { source: vBriImg; anchors.fill: vBriImg; colorization: 1.0; colorizationColor: Config.cTertiary }
            WheelHandler { acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad; onWheel: ev => Config.adjustBrightness(ev.angleDelta.y > 0) }
            MouseArea {
                anchors.fill: parent; hoverEnabled: true; acceptedButtons: Qt.NoButton
                onEntered: Config.vBriHovered = true; onExited: Config.vBriHovered = false
            }
        }

        Item {
            Layout.alignment: Qt.AlignHCenter; width: 24; height: 24
            Image { id: vBatImg; anchors.centerIn: parent; width: 18; height: 18; smooth: true; mipmap: true; fillMode: Image.PreserveAspectFit
                source: Config.batCharging ? (Config.batPercent >= 100 ? Qt.resolvedUrl("icons/battery-full.svg") : Qt.resolvedUrl("icons/battery-charge.svg"))
                      : Config.batPercent > 80 ? Qt.resolvedUrl("icons/battery-8.svg") : Config.batPercent > 60 ? Qt.resolvedUrl("icons/battery-6.svg")
                      : Config.batPercent > 40 ? Qt.resolvedUrl("icons/battery-4.svg") : Config.batPercent > 20 ? Qt.resolvedUrl("icons/battery-2.svg") : Qt.resolvedUrl("icons/battery-0.svg") }
            MultiEffect { source: vBatImg; anchors.fill: vBatImg; colorization: 1.0; colorizationColor: Config.batCharging ? "#a6e3a1" : Config.batPercent > 30 ? "#a6e3a1" : "#f38ba8" }
            MouseArea { anchors.fill: parent; hoverEnabled: true; acceptedButtons: Qt.NoButton
                onEntered: Config.vBatHovered = true; onExited: Config.vBatHovered = false }
        }

        Item {
            Layout.alignment: Qt.AlignHCenter; width: 24; height: 24
            Image { id: vWifiImg; anchors.centerIn: parent; width: 18; height: 18; smooth: true; mipmap: true; fillMode: Image.PreserveAspectFit
                source: Config.networkName ? Qt.resolvedUrl("icons/wifi-2-filled.svg") : Qt.resolvedUrl("icons/wifi-4-filled.svg") }
            MultiEffect { source: vWifiImg; anchors.fill: vWifiImg; colorization: 1.0; colorizationColor: Config.wifiOpen ? Config.cPrimary : Config.networkName ? Config.cSecondary : "#555" }
            MouseArea { anchors.fill: parent; onClicked: Config.wifiOpen = !Config.wifiOpen }
        }

        Item {
            Layout.alignment: Qt.AlignHCenter; width: 24; height: 24
            property bool btOn:   Bluetooth.defaultAdapter?.enabled ?? false
            property bool btConn: Bluetooth.devices.values.some(d => d.connected)
            Image { id: vBtImg; anchors.centerIn: parent; width: 18; height: 18; smooth: true; mipmap: true; fillMode: Image.PreserveAspectFit
                source: parent.btOn ? (parent.btConn ? Qt.resolvedUrl("icons/bluetooth-connected-filled.svg") : Qt.resolvedUrl("icons/bluetooth-filled.svg")) : Qt.resolvedUrl("icons/bluetooth-disabled-filled.svg") }
            MultiEffect { source: vBtImg; anchors.fill: vBtImg; colorization: 1.0; colorizationColor: parent.btOn ? (parent.btConn ? Config.cPrimary : Config.cSecondary) : "#555" }
            MouseArea { anchors.fill: parent; onClicked: Config.btOpen = !Config.btOpen }
        }
    }
}
