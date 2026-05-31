import Quickshell
import "."
import Quickshell.Wayland
import QtQuick

PanelWindow {
    id: tip
    visible: Config.isVertical && (Config.vVolHovered || Config.vBriHovered || Config.vBatHovered)

    property string tipText: Config.vVolHovered ? Config.vVolTooltip
                           : Config.vBriHovered ? Config.vBriTooltip
                           : Config.vBatHovered ? Config.vBatTooltip : ""

    anchors.left:   Config.barPosition === "left"
    anchors.right:  Config.barPosition === "right"
    anchors.bottom: true
    margins {
        left:   Config.barPosition === "left"  ? Config.barThickness + 6 : 0
        right:  Config.barPosition === "right" ? Config.barThickness + 6 : 0
        bottom: Config.vVolHovered ? 133 : Config.vBriHovered ? 101 : 69
    }
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
    exclusionMode: ExclusionMode.Ignore
    color: "transparent"
    // Фиксированный размер — иначе при первом показе Wayland коммитит 0×0
    implicitWidth: 120
    implicitHeight: 36

    Rectangle {
        anchors.fill: parent; radius: 8
        color: Qt.rgba(Config.cSurface.r, Config.cSurface.g, Config.cSurface.b, 0.95)
        border.color: Qt.rgba(Config.cPrimary.r, Config.cPrimary.g, Config.cPrimary.b, 0.28); border.width: 1
        Text {
            anchors.centerIn: parent
            text: tip.tipText
            font.family: "JetBrainsMono Nerd Font Mono"
            font.pixelSize: 15; font.weight: Font.Bold
            color: Config.cOnSurface
        }
    }
}
