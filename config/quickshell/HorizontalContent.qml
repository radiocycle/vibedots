import Quickshell
import "."
import Quickshell.Wayland
import Quickshell.Hyprland
import Quickshell.Services.Pipewire
import Quickshell.Services.UPower
import Quickshell.Services.SystemTray
import Quickshell.Bluetooth
import QtQuick
import QtQuick.Layouts
import QtQuick.Effects

RowLayout {
    spacing: 0

    // ── LEFT: Workspaces + Player ─────────────────────────────────
    RowLayout {
        spacing: 6

        RowLayout {
            spacing: 3
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
                    required property int modelData
                    property var ws: {
                        for (var i = 0; i < Hyprland.workspaces.values.length; i++)
                            if (Hyprland.workspaces.values[i].id === modelData) return Hyprland.workspaces.values[i]
                        return null
                    }
                    property bool focused:  ws ? ws.focused : false
                    property bool occupied: ws ? ws.clientCount > 0 : false
                    implicitWidth: wsRect.width + 2; implicitHeight: Config.barThickness
                    Rectangle {
                        id: wsRect
                        anchors.verticalCenter: parent.verticalCenter
                        width: focused ? 30 : occupied ? 22 : 18; height: 24; radius: 6
                        color: focused ? Qt.rgba(Config.cPrimary.r, Config.cPrimary.g, Config.cPrimary.b, 0.18)
                               : occupied ? Qt.rgba(Config.cPrimary.r, Config.cPrimary.g, Config.cPrimary.b, 0.07) : "transparent"
                        border.color: Qt.rgba(Config.cPrimary.r, Config.cPrimary.g, Config.cPrimary.b, focused ? 0.50 : 0.16); border.width: 1
                        Behavior on width { NumberAnimation { duration: 150 } }
                        Text {
                            anchors.centerIn: parent; visible: true; text: modelData
                            font.family: "JetBrainsMono Nerd Font Mono"; font.pixelSize: 14; font.bold: focused
                            color: focused ? Config.cPrimary : occupied ? Config.cOnSurfaceVar : Qt.rgba(Config.cOnSurfaceVar.r, Config.cOnSurfaceVar.g, Config.cOnSurfaceVar.b, 0.45)
                        }
                        Rectangle {
                            anchors { bottom: parent.bottom; horizontalCenter: parent.horizontalCenter; bottomMargin: 2 }
                            visible: occupied && !focused; width: 3; height: 3; radius: 2; color: Config.cOnSurfaceVar; opacity: 0.6
                        }
                    }
                    MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: Hyprland.dispatch("workspace " + modelData) }
                }
            }
        }

        Rectangle { width: 1; height: 20; color: Qt.rgba(Config.cPrimary.r, Config.cPrimary.g, Config.cPrimary.b, 0.15); visible: Config.currentPlayer !== null }

        Text {
            visible: ToplevelManager.activeToplevel !== null
            text: { var t = ToplevelManager.activeToplevel?.title ?? ""; return t.length > 30 ? t.slice(0, 27) + "…" : t }
            font.family: "JetBrainsMono Nerd Font Mono"; font.pixelSize: 14
            color: Qt.rgba(Config.cOnSurface.r, Config.cOnSurface.g, Config.cOnSurface.b, 0.60); font.italic: true
        }

        Item {
            visible: Config.currentPlayer !== null
            implicitHeight: Config.barThickness; implicitWidth: visible ? playerPill.implicitWidth + 4 : 0
            Rectangle {
                id: playerPill; anchors.verticalCenter: parent.verticalCenter
                height: 28; implicitWidth: playerRow.implicitWidth + 16; radius: height / 2
                color: Qt.rgba(Config.cSurfaceCont.r, Config.cSurfaceCont.g, Config.cSurfaceCont.b, 0.90)
                border.color: Qt.rgba(Config.cPrimary.r, Config.cPrimary.g, Config.cPrimary.b, playerMa.containsMouse ? 0.30 : 0.14); border.width: 1
                Rectangle { anchors.fill: parent; radius: parent.radius; color: Qt.rgba(Config.cPrimary.r, Config.cPrimary.g, Config.cPrimary.b, playerMa.containsMouse ? 0.06 : 0) }
                MouseArea {
                    id: playerMa; anchors.fill: parent; hoverEnabled: true; acceptedButtons: Qt.MiddleButton
                    onClicked: { if (Config.currentPlayer) Config.currentPlayer.togglePlaying() }
                    onEntered: Config.showPlayer(); onExited: Config.hidePlayer()
                }
                RowLayout {
                    id: playerRow; anchors.centerIn: parent; spacing: 6
                    Text { text: Config.playerPlaying ? "󰐊" : "󰏤"; font.family: "JetBrainsMono Nerd Font Mono"; font.pixelSize: 15; color: Config.cPrimary }
                    Text {
                        text: {
                            var p = Config.currentPlayer; if (!p) return ""
                            var s = (p.trackArtist || "") ? p.trackArtist + " — " + p.trackTitle : p.trackTitle || ""
                            return s.length > 35 ? s.slice(0, 32) + "…" : s
                        }
                        font.family: "JetBrainsMono Nerd Font Mono"; font.pixelSize: 15; color: Config.cOnSurface
                    }
                }
            }
        }
    }

    Item { Layout.fillWidth: true }
    Item { Layout.fillWidth: true }

    // ── RIGHT: status pills ───────────────────────────────────────
    RowLayout {
        spacing: 3

        Pill {
            property var  sink:  Pipewire.defaultAudioSink
            property real vol:   sink && sink.audio ? Math.min(sink.audio.volume, 1.5) : 0
            property bool muted: sink && sink.audio ? sink.audio.muted : false
            svg: muted ? Qt.resolvedUrl("icons/speaker-mute-filled.svg")
                       : vol > 0.5 ? Qt.resolvedUrl("icons/speaker-2-filled.svg")
                       : vol > 0.0 ? Qt.resolvedUrl("icons/speaker-1.svg") : Qt.resolvedUrl("icons/speaker-0.svg")
            label: muted ? "mute" : Math.round(vol * 100) + "%"; iconColor: muted ? "#666" : Config.cTertiary
            WheelHandler {
                acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
                onWheel: ev => { var s = Pipewire.defaultAudioSink; if (s && s.audio) s.audio.volume = Math.max(0, Math.min(1.5, s.audio.volume + (ev.angleDelta.y > 0 ? 0.05 : -0.05))) }
            }
            MouseArea { anchors.fill: parent; acceptedButtons: Qt.MiddleButton; onClicked: { var s = Pipewire.defaultAudioSink; if (s && s.audio) s.audio.muted = !s.audio.muted } }
        }

        Pill {
            svg: Qt.resolvedUrl("icons/weather-sunny-filled.svg")
            label: Math.round(Config.brightness * 100) + "%"; iconColor: Config.cTertiary
            WheelHandler { acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad; onWheel: ev => Config.adjustBrightness(ev.angleDelta.y > 0) }
        }

        Pill {
            property int  pct:      Config.batPercent
            property bool charging: Config.batCharging
            svg: {
                if (charging) return pct >= 100 ? Qt.resolvedUrl("icons/battery-full.svg") : Qt.resolvedUrl("icons/battery-charge.svg")
                if (pct > 80) return Qt.resolvedUrl("icons/battery-8.svg"); if (pct > 60) return Qt.resolvedUrl("icons/battery-6.svg")
                if (pct > 40) return Qt.resolvedUrl("icons/battery-4.svg"); if (pct > 20) return Qt.resolvedUrl("icons/battery-2.svg")
                return Qt.resolvedUrl("icons/battery-0.svg")
            }
            label: pct + "%"; iconColor: charging ? "#a6e3a1" : pct > 30 ? "#a6e3a1" : "#f38ba8"
            MouseArea { anchors.fill: parent; hoverEnabled: true; onEntered: Config.batHovered = true; onExited: Config.batHovered = false }
        }

        Pill {
            svg: { switch (PowerProfiles.profile) { case PowerProfile.PowerSaver: return Qt.resolvedUrl("icons/leaf-two-filled.svg"); case PowerProfile.Performance: return Qt.resolvedUrl("icons/fire-filled.svg"); default: return Qt.resolvedUrl("icons/power-filled.svg") } }
            label: ""; iconColor: { switch (PowerProfiles.profile) { case PowerProfile.PowerSaver: return Config.cTertiary; case PowerProfile.Performance: return Config.cError; default: return Config.cSecondary } }
            MouseArea {
                anchors.fill: parent
                onClicked: {
                    if (PowerProfiles.hasPerformanceProfile) {
                        switch (PowerProfiles.profile) {
                            case PowerProfile.PowerSaver:  PowerProfiles.profile = PowerProfile.Balanced;    break
                            case PowerProfile.Balanced:    PowerProfiles.profile = PowerProfile.Performance; break
                            case PowerProfile.Performance: PowerProfiles.profile = PowerProfile.PowerSaver;  break
                        }
                    } else { PowerProfiles.profile = PowerProfiles.profile === PowerProfile.Balanced ? PowerProfile.PowerSaver : PowerProfile.Balanced }
                }
            }
        }

        Pill {
            property bool btOn:   Bluetooth.defaultAdapter?.enabled ?? false
            property bool btConn: Bluetooth.devices.values.some(d => d.connected)
            svg: btOn ? (btConn ? Qt.resolvedUrl("icons/bluetooth-connected-filled.svg") : Qt.resolvedUrl("icons/bluetooth-filled.svg")) : Qt.resolvedUrl("icons/bluetooth-disabled-filled.svg")
            label: { if (!btOn) return "off"; var c = Bluetooth.devices.values.filter(d => d.connected); return c.length > 0 ? c[0].name.slice(0, 10) : "" }
            iconColor: btOn ? (btConn ? Config.cPrimary : Config.cSecondary) : "#555"
            MouseArea { anchors.fill: parent; onClicked: Config.btOpen = !Config.btOpen }
        }

        Pill {
            svg: Config.networkName ? Qt.resolvedUrl("icons/wifi-2-filled.svg") : Qt.resolvedUrl("icons/wifi-4-filled.svg")
            label: ""; iconColor: Config.wifiOpen ? Config.cPrimary : (Config.networkName ? Config.cSecondary : "#555"); hoverable: true
            MouseArea { anchors.fill: parent; onClicked: Config.wifiOpen = !Config.wifiOpen }
        }

        Rectangle {
            visible: SystemTray.items.values.length > 0; height: 28; implicitWidth: trayRow.implicitWidth + 12; radius: height / 2
            color: Qt.rgba(Config.cSurfaceCont.r, Config.cSurfaceCont.g, Config.cSurfaceCont.b, 0.90)
            border.color: Qt.rgba(Config.cPrimary.r, Config.cPrimary.g, Config.cPrimary.b, 0.14); border.width: 1
            RowLayout {
                id: trayRow; anchors.centerIn: parent; spacing: 2
                Repeater {
                    model: SystemTray.items.values
                    delegate: Item {
                        id: trayItem; required property SystemTrayItem modelData; width: 20; height: 20
                        Image { anchors.centerIn: parent; width: 18; height: 18; source: trayItem.modelData.icon; smooth: true; mipmap: true }
                        QsMenuAnchor { id: trayMenu; menu: trayItem.modelData.menu; anchor.item: trayItem; anchor.gravity: Edges.Bottom; anchor.edges: Edges.Bottom; anchor.adjustment: PopupAdjustment.SlideX }
                        MouseArea {
                            anchors.fill: parent; acceptedButtons: Qt.LeftButton | Qt.RightButton
                            onClicked: ev => { if (ev.button === Qt.LeftButton) trayItem.modelData.activate(); else if (trayItem.modelData.hasMenu) trayMenu.open() }
                        }
                    }
                }
            }
        }

        Pill { icon: ""; label: Config.layoutName; iconColor: Config.cPrimary; implicitWidth: 42; hoverable: false }
    }
}
