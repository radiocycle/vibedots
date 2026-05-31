import Quickshell
import "."
import Quickshell.Wayland
import Quickshell.Services.Pipewire
import QtQuick
import QtQuick.Layouts

PanelWindow {
    id: osdWin
    property bool   _show: false
    property string osdIcon: ""
    visible: Config.isVertical && _show

    property real osdValue: {
        if (osdIcon === "volume")     { var s = Pipewire.defaultAudioSink; return (s && s.audio && !s.audio.muted) ? Math.min(1, s.audio.volume) : 0 }
        if (osdIcon === "brightness") return Config.brightness
        if (osdIcon === "bat")        return Config.batPercent / 100
        return 0
    }
    property string osdText: {
        if (osdIcon === "volume")     { var s = Pipewire.defaultAudioSink; if (!s || !s.audio) return "—"; return s.audio.muted ? "Mute" : Math.round(Math.min(s.audio.volume, 1.5) * 100) + "%" }
        if (osdIcon === "brightness") return Math.round(Config.brightness * 100) + "%"
        if (osdIcon === "bat")        return Config.batPercent + "%" + (Config.batCharging ? " · ⚡" : "")
        return ""
    }

    function trigger(icon) { osdIcon = icon; _show = true; osdHideTimer.restart() }
    Timer { id: osdHideTimer; interval: 1800; onTriggered: osdWin._show = false }

    Connections { target: Config; function onOsdRequested(icon) { osdWin.trigger(icon) } }

    anchors.bottom: true; margins { bottom: 48 }
    WlrLayershell.layer: WlrLayer.Overlay; WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
    exclusionMode: ExclusionMode.Ignore; color: "transparent"
    implicitWidth: 180; implicitHeight: 56

    Rectangle {
        anchors.fill: parent; radius: 16
        color: Qt.rgba(Config.cSurface.r, Config.cSurface.g, Config.cSurface.b, 0.95)
        border.color: Qt.rgba(Config.cPrimary.r, Config.cPrimary.g, Config.cPrimary.b, 0.25); border.width: 1
        ColumnLayout { anchors.centerIn: parent; spacing: 7
            Rectangle { Layout.alignment: Qt.AlignHCenter; width: 140; height: 4; radius: 2; color: Qt.rgba(Config.cPrimary.r, Config.cPrimary.g, Config.cPrimary.b, 0.18)
                Rectangle { width: parent.width * osdWin.osdValue; height: parent.height; radius: 2; color: Config.cPrimary; Behavior on width { NumberAnimation { duration: 100 } } }
            }
            Text { Layout.alignment: Qt.AlignHCenter; text: osdWin.osdText; font.family: "JetBrainsMono Nerd Font Mono"; font.pixelSize: 15; font.weight: Font.Bold; color: Config.cOnSurface }
        }
    }
}
